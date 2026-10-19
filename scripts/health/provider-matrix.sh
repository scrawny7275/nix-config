#!/usr/bin/env bash
# provider-matrix.sh — opencode provider/model health: one classifier, three run modes.
#
# Modes:
#   --scope=narrow (default)  Stateful. GET /v1/models sanity + 2 parallel probes on the
#       nvidia key (z-ai/glm-5.3, nemotron control), each row appended
#       to state.csv. On roll-up state change (HEALTHY/DEGRADED/BROKEN) prints a TRANSITION
#       line to stdout (-> user journal) and notify-sends. First run records a baseline
#       without notifying. (2026-10-16: kimi-k3 probe dropped — EOL'd on NVIDIA Build,
#       every probe a deterministic HTTP 410; its 310s HANG-confirm went with it.)
#   --scope=all    Snapshot over every configured provider x model in opencode.json
#       (URLs/keys derived from its {file:...} tokens — the same source opencode uses).
#       No state transitions, no notify. omniroute -> UNDEF (auth mismatch unresolved);
#       providers with no configured models -> SKIPPED row.
#   --daily        --scope=all + 24h digest of state.csv ->
#       $STATE_DIR/matrix-<date>.csv, latest-matrix.csv, summary-24h-<date>.txt,
#       latest-summary-24h.txt, stdout digest, one notify-send. Runs at 08:00 (timer),
#       catch-up on wake (Persistent=true, no WakeSystem).
#
# Classes: OK | SLOW (200, TTFB>30s) | BUDGET-EXHAUSTED (200, finish=length, all tokens
#   reasoning — benign probe artifact) | EMPTY-STOP (200, finish=stop, no content, no
#   tool_calls — first seen as a kimi-k3 quirk, pre-EOL) | HANG-SUSPECT (connect ok, 0 bytes >=120s) |
#   HANG-DEFINITIVE (0 bytes >=300s or gateway 504) | ENTITLED-404 | NOT-FOUND | AUTH |
#   EXTERNAL-ONLY | QUOTA | RATE | OVERLOAD | UNDEF | SKIPPED | LOCAL-NET | STALL | UNKNOWN
# Roll-ups: HEALTHY={OK,SLOW,BUDGET-EXHAUSTED}  DEGRADED={EMPTY-STOP,RATE,OVERLOAD,STALL}
#           BROKEN=everything else.
# Thresholds/caps are identical across modes — edit the constants block only.
# Exit code = monitor health only: 0 ok, 70 tool/config broken, 72 usage. Probe outcomes
# are data, never failures.
set -uo pipefail

# ---- constants -----------------------------------------------------------
SLOW_TTFB=30          # 200 but TTFB above this -> SLOW
HANG_SUSPECT=120      # connect ok + 0 bytes at this age -> HANG-SUSPECT
CHAT_CAP=130          # chat probe --max-time (slow-but-alive glm TTFB measured 57-84s)
CTRL_CAP=30           # control probe cap (nemotron answers <1s when healthy)
PROBE_TOKENS=500      # floor: below this, reasoning models legitimately emit no content

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/provider-health"
STATE_CSV="$STATE_DIR/state.csv"
LAST_DIR="$STATE_DIR/last"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
SCOPE="narrow"

while [ $# -gt 0 ]; do
  case "$1" in
    --scope=narrow) SCOPE="narrow" ;;
    --scope=all)    SCOPE="all" ;;
    --daily)        SCOPE="daily" ;;
    -h|--help)      sed -n '2,28p' "$0"; exit 0 ;;
    *)              echo "unknown arg: $1" >&2; exit 72 ;;
  esac
  shift
done

die()  { echo "MONITOR-BROKEN: $1" >&2; exit "${2:-70}"; }
have() { command -v "$1" >/dev/null 2>&1; }

for t in curl python3 awk date mktemp flock tr; do
  have "$t" || die "missing tool: $t" 70
done
[ -r "$CFG" ] || die "cannot read $CFG"
mkdir -p "$STATE_DIR" "$LAST_DIR" || die "cannot create $STATE_DIR"
[ -f "$STATE_CSV" ] || \
  echo 'ts_epoch,ts_utc,scope,probe,http,ttfb_s,total_s,bytes,class,rollup,detail' > "$STATE_CSV"
# single-instance guard: overlapping runs (timer catch-up vs hand-run) just skip
exec 9>"$STATE_DIR/.lock"
flock -w 60 9 || { echo "another provider-matrix instance holds the lock; skipping"; exit 0; }

notify() { # title body — WARN on failure, never silent
  if have notify-send; then
    notify-send --app-name=provider-health "$1" "$2" 2>/dev/null \
      || echo "WARN notify-send failed: $1 — $2" >&2
  else
    echo "WARN notify-send unavailable: $1 — $2" >&2
  fi
}

# ---- target discovery: opencode.json {file:...} tokens -------------------
# TSV: provider, model, chat-url, api-key(-resolved|[none]), mark
targets_from_cfg() {
python3 - "$CFG" <<'PY'
import json, re, sys
cfg = json.load(open(sys.argv[1]))
tok = re.compile(r"\{file:(.*?)\}")
def sub_file(s):
    return tok.sub(lambda m: open(m.group(1)).read().strip(), s or "")
def resolve_key(s):
    if not s: return "[none]"
    m = tok.fullmatch(s)
    if m:
        try: return open(m.group(1)).read().strip()
        except OSError: return "[unreadable]"
    return s
for name, p in sorted(cfg.get("provider", {}).items()):
    opts = p.get("options", {})
    base = sub_file(opts.get("baseURL") or "").rstrip("/")
    key = resolve_key(opts.get("apiKey"))
    models = list(p.get("models", {}).keys())
    if not models:
        print(name + "\t[no-models]\t-\t-\tSKIPPED no models configured")
        continue
    for m in sorted(models):
        print(name + "\t" + m + "\t" + base + "/chat/completions\t" + key + "\t")
PY
}

# ---- classification ------------------------------------------------------
# $1=http $2=ttfb $3=total $4=bytes $5=bodyfile $6=cap $7=connect $8=slow_ttfb $9=hang_suspect
classify_http() {
python3 - "$@" <<'PY'
import sys, json
http, ttfb, total, nbytes, body, cap, connect, slow, hsuspect = sys.argv[1:10]
ttfb, total, cap, connect = float(ttfb), float(total), float(cap), float(connect)
slow, hsuspect = float(slow), float(hsuspect)
try: nbytes = int(nbytes)
except ValueError: nbytes = 0
def trim(s, n=140):
    s = " ".join((s or "").split())
    return s[:n-1] + "..." if len(s) > n else s
def read_body():
    try: return open(body).read()
    except OSError: return ""

if http == "000":
    if connect >= total - 0.5:                    # never connected (refused/DNS/connect-timeout)
        print("LOCAL-NET\tconnect failed after %.1fs" % total); sys.exit()
    if total >= hsuspect:
        print("HANG-SUSPECT\tconnect ok, 0 bytes at %.0fs" % total); sys.exit()
    print("STALL\tconnect ok, 0 bytes at %.0fs" % total); sys.exit()
if http == "504":
    print("HANG-DEFINITIVE\tgateway 504 after %.0fs" % total); sys.exit()
if http == "429": print("RATE\t429"); sys.exit()
if http == "503": print("OVERLOAD\t503"); sys.exit()
if http == "402": print("QUOTA\t" + trim(read_body())); sys.exit()
if http in ("401", "403"):
    txt = read_body()
    if "FreeTierError" in txt or "only be used from within" in txt:
        print("EXTERNAL-ONLY\t" + trim(txt)); sys.exit()
    print("AUTH\t" + trim(txt)); sys.exit()
if http == "404":
    txt = read_body()
    if "Not found for account" in txt: print("ENTITLED-404\t" + trim(txt)); sys.exit()
    print("NOT-FOUND\t" + trim(txt)); sys.exit()
if http != "200":
    print("UNKNOWN\thttp=" + http + " " + trim(read_body())); sys.exit()
try:
    d = json.load(open(body))
except Exception as e:
    print("UNKNOWN\t200 unparseable: " + trim(str(e), 80)); sys.exit()
if isinstance(d.get("error"), (dict, str)):        # openrouter-style 200-wrapped errors
    e = d["error"]
    msg = e.get("message", "") if isinstance(e, dict) else str(e)
    print("UNKNOWN\t200-with-error: " + trim(msg)); sys.exit()
ch = (d.get("choices") or [{}])[0]
msg = ch.get("message") or {}
fin = ch.get("finish_reason") or ""
content = (msg.get("content") or "").strip()
tools = msg.get("tool_calls") or []
u = d.get("usage") or {}
rtok = (u.get("completion_tokens_details") or {}).get("reasoning_tokens") or 0
ctok = u.get("completion_tokens") or 0
if fin == "stop" and not content and not tools:
    print("EMPTY-STOP\tfinish=stop output=0 (%dr/%dc)" % (rtok, ctok)); sys.exit()
if fin == "length" and not content and not tools and rtok >= ctok - 1:
    print("BUDGET-EXHAUSTED\tall-reasoning %dr/%dc" % (rtok, ctok)); sys.exit()
kind = "tools" if tools else ("content" if content else "empty")
cls = "SLOW" if ttfb > slow else "OK"
print("%s\tfinish=%s %s ttfb=%.1fs" % (cls, fin, kind, ttfb))
PY
}

rollup() {
  case "$1" in
    OK|SLOW|BUDGET-EXHAUSTED) echo "HEALTHY" ;;
    EMPTY-STOP|RATE|OVERLOAD|STALL) echo "DEGRADED" ;;
    *) echo "BROKEN" ;;
  esac
}

san() { echo "$1" | tr '/' '_'; }

# ---- probe execution -----------------------------------------------------
# run_probe LABEL MODEL URL KEY CAP TOKENS TOOLS(yes|no) SCOPE
#   -> stdout: "http<TAB>ttfb<TAB>total<TAB>bytes<TAB>class<TAB>detail"
run_probe() {
  # $1=label $2=model $3=url $4=key $5=cap $6=tokens $7=tools $8=scope (label/scope kept for log greppability)
  local model="$2" url="$3" key="$4" cap="$5" tokens="$6" tools="$7"
  local tmp cfgf body req out http connect ttfb total bytes class detail
  tmp=$(mktemp -d) || die "mktemp failed"
  cfgf="$tmp/cfg"; body="$tmp/body"; req="$tmp/req"
  {
    printf 'url = "%s"\n' "$url"
    printf 'header = "Content-Type: application/json"\n'
    if [ "$key" != "[none]" ] && [ -n "$key" ]; then
      printf 'header = "Authorization: Bearer %s"\n' "$key"
    fi
    printf 'retry = "0"\n'
  } > "$cfgf"
  chmod 600 "$cfgf"
  if [ "$tools" = "yes" ]; then
    printf '{"model":"%s","max_tokens":%s,"messages":[{"role":"user","content":"What is 17*23? Use the calc tool."}],"tools":[{"type":"function","function":{"name":"calc","description":"multiply two numbers","parameters":{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}}}]}' \
      "$model" "$tokens" > "$req"
  else
    printf '{"model":"%s","max_tokens":%s,"messages":[{"role":"user","content":"Reply with exactly the word OK"}]}' \
      "$model" "$tokens" > "$req"
  fi
  out=$(curl -sS -K "$cfgf" --data-binary @"$req" --max-time "$cap" -o "$body" \
        -w '%{http_code} %{time_connect} %{time_starttransfer} %{time_total} %{size_download}' 2>/dev/null)
  read -r http connect ttfb total bytes <<< "$out"
  [ -n "$http" ] || { http=000; connect=0; ttfb=0; total=$cap; bytes=0; }
  IFS=$'\t' read -r class detail < <(classify_http "$http" "$ttfb" "$total" "$bytes" "$body" "$cap" "$connect" "$SLOW_TTFB" "$HANG_SUSPECT")
  rm -rf "$tmp"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$http" "$ttfb" "$total" "$bytes" "$class" "$detail"
}

csv_row() { # SCOPE PROBE HTTP TTFB TOTAL BYTES CLASS DETAIL
  local ru; ru=$(rollup "$7")
  printf '%s,%s,%s,%s,%s,%.1f,%.1f,%s,%s,%s,"%s"\n' \
    "$(date +%s)" "$(date -u +%FT%TZ)" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$ru" \
    "${8//\"/\"\"}" >> "$STATE_CSV"
  # The transition state machine is narrow-only: matrix/daily rows are snapshots and
  # must not shift narrow baselines (bug found live 2026-10-05: a matrix EMPTY-STOP
  # row forged a DEGRADED baseline for kimi and fabricated a spurious transition).
  [ "$1" = "narrow" ] && echo "$ru" > "$LAST_DIR/$(san "$2")"
}

last_rollup() { cat "$LAST_DIR/$(san "$1")" 2>/dev/null || echo "NEW"; }

transition() { # PROBE OLD NEW CLASS DETAIL — journal + notify; NEW baselines are silent
  [ "$2" = "$3" ] && return 0
  if [ "$2" != "NEW" ]; then
    echo "TRANSITION $1: $2 -> $3 ($4: $5)"
    notify "provider-health: $1" "$2 -> $3 — $4"
  else
    echo "BASELINE $1: $3 ($4)"
  fi
}

# ---- narrow: default, stateful, the 20-min timer body --------------------
narrow() {
  local base key shttp
  key=$(targets_from_cfg | awk -F'\t' '$1=="nvidia" {print $4; exit}')
  base=$(targets_from_cfg | awk -F'\t' '$1=="nvidia" {print $3; exit}' | sed 's|/chat/completions$||')
  [ -n "$key" ] && [ "$key" != "[none]" ] && [ "$key" != "[unreadable]" ] || die "nvidia key unresolved from $CFG"
  [ -n "$base" ] || die "nvidia baseURL unresolved from $CFG"

  shttp=$(curl -sS --max-time "$CTRL_CAP" -o /dev/null -w '%{http_code}' \
          -H "Authorization: Bearer $key" "$base/models" 2>/dev/null)
  if [ "$shttp" = "000" ]; then
    echo "TRANSITION net: GET $base/models unreachable -> LOCAL-NET for all nvidia probes"
    local m old
    for m in "nvidia/z-ai/glm-5.3" "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"; do
      old=$(last_rollup "$m")
      csv_row narrow "$m" 000 0 "$CTRL_CAP" 0 LOCAL-NET "models GET 000 (net sanity)"
      transition "$m" "$old" "BROKEN" "LOCAL-NET" "models GET 000"
    done
    return 0
  fi

  run_probe "glm" "z-ai/glm-5.3" "$base/chat/completions" "$key" \
            "$CHAT_CAP" "$PROBE_TOKENS" yes narrow > "$STATE_DIR/.p1" &
  run_probe "ctrl" "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning" "$base/chat/completions" "$key" \
            "$CTRL_CAP" "$PROBE_TOKENS" no narrow > "$STATE_DIR/.p2" &
  wait

  local i probe http ttfb total bytes class detail old ru_new
  for i in 1 2; do
    case $i in
      1) probe="nvidia/z-ai/glm-5.3" ;;
      2) probe="nvidia/nemotron-3-nano-omni-30b-a3b-reasoning" ;;
    esac
    IFS=$'\t' read -r http ttfb total bytes class detail < "$STATE_DIR/.p$i"
    rm -f "$STATE_DIR/.p$i"
    old=$(last_rollup "$probe")
    ru_new=$(rollup "$class")
    csv_row narrow "$probe" "$http" "$ttfb" "$total" "$bytes" "$class" "$detail"
    transition "$probe" "$old" "$ru_new" "$class" "$detail"
  done
}

# ---- all: snapshot over configured providers ------------------------------
allmode() {
  # Concurrency cap: 11 parallel nvidia probes self-induced an OVERLOAD (503) on the
  # control model in the first live run (2026-10-05) — same-key burst. Cap at 6.
  local MAX_CONC=6 running=0 n=0
  local tmp; tmp=$(mktemp -d) || die "mktemp failed"
  targets_from_cfg > "$tmp/targets.tsv"
  local prov model url key mark rowfile probe
  while IFS=$'\t' read -r prov model url key mark; do
    n=$((n + 1))
    rowfile="$tmp/$n.row"   # probe name lives in the file; filenames are opaque (model ids
                            # can contain '_' — a tr round-trip would corrupt them)
    if [ "$prov" = "omniroute" ]; then
      printf '%s\t0\t0\t0\t0\tUNDEF\tauth mismatch unresolved (apiKey validation vs server)\n' "$prov/$model" > "$rowfile"
    elif [ -n "$mark" ]; then
      printf '%s\t0\t0\t0\t0\tSKIPPED\t%s\n' "$prov/$model" "$mark" > "$rowfile"
    else
      run_probe "all" "$model" "$url" "$key" "$CHAT_CAP" "$PROBE_TOKENS" no all \
        | { printf '%s\t' "$prov/$model"; cat; } > "$rowfile" &
    fi
    running=$((running + 1))
    if [ "$running" -ge "$MAX_CONC" ]; then
      wait -n
      running=$((running - 1))
    fi
  done < "$tmp/targets.tsv"
  wait
  local f http ttfb total bytes class detail
  for f in "$tmp"/*.row; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r probe http ttfb total bytes class detail < "$f"
    csv_row all "$probe" "$http" "$ttfb" "$total" "$bytes" "$class" "$detail"
  done
  rm -rf "$tmp"
}

# ---- daily: matrix + digest + notify -------------------------------------
daily() {
  local day now cutoff matrix summary
  day=$(date +%F)
  allmode
  matrix="$STATE_DIR/matrix-$day.csv"
  awk -F, -v d="$day" 'NR==1 || ($3=="all" && index($2, d)==1)' "$STATE_CSV" > "$matrix"
  cp -f "$matrix" "$STATE_DIR/latest-matrix.csv"
  now=$(date +%s); cutoff=$((now - 86400))
  summary="$STATE_DIR/summary-24h-$day.txt"
  {
    echo "provider-health 24h digest — $(date -u +%FT%TZ)"
    echo
    echo "24h class counts by probe:"
    awk -F, -v c="$cutoff" 'NR>1 && $1>=c {n[$4"  "$9]++}
      END {for (k in n) print "  "k" x"n[k]}' "$STATE_CSV" | sort
    echo
    echo "roll-up transitions in last 24h:"
    awk -F, -v c="$cutoff" 'NR>1 && $1>=c {
      if (s[$4] && s[$4]!=$10) print "  " $2" "$4" "s[$4]" -> "$10; s[$4]=$10}' "$STATE_CSV"
    echo
    echo "matrix: $matrix"
    echo "state:  $STATE_CSV"
  } > "$summary"
  cp -f "$summary" "$STATE_DIR/latest-summary-24h.txt"
  cat "$summary"
  notify "provider-health: daily report ready" "latest-summary-24h.txt + latest-matrix.csv in $STATE_DIR"
}

case "$SCOPE" in
  narrow) narrow ;;
  all)    allmode ;;
  daily)  daily ;;
  *)      die "bad scope: $SCOPE" 72 ;;
esac
echo "provider-matrix: $SCOPE done at $(date -u +%FT%TZ)"
exit 0
