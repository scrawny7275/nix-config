# Plan: Anytype Local API read-only trial (execution-ready)

**Status:** approved scope "Anytype only" (2026-09-30). Blocked on: (a) plan-mode exit toggle, (b) Phase 0 key creation by user.

**Revision 2026-09-30 (post-sparring pass):** (1) wrapper is now a DECLARATIVE flake module, not a scratch `~/.local/bin` file (user's artifact-placement rule; verified precedent: all existing `~/.local/bin/*` entries are `/nix/store/*-home-manager-files` symlinks); (2) wrapper hardened to **GET-only** — non-GET is structurally denied (trial read-only must be mechanism, not prose); (3) log moved to XDG state dir (runtime-state exception, only its location declared); (4) declarative-artifacts hard rule + enforcement options added; (5) PixelRAG reconsideration + E1/E2 measurement design folded into the deferred browser-trial section.

**Revision 2026-09-30c (user directives — scope expansion; NOTE: this revision's prior edits were rolled back by plan-tooling between turns and were re-applied):** (1) scope is now **full read + sandbox-scoped write** (user requires agents to read/write/modify/refactor; read-only was a risk-shape, not the requirement — writes confined to one designated sandbox space until Anytype 0.57.x/v2 guards exist; widening is an explicit user override); (2) API key via **sops-nix templates** (verdict accepted; plain-600-file retired); (3) naming clarified: component is a thin CLI client over the Local API (NOT a nix-pkg wrapper, NOT an MCP) — the "self-developed MCP" charge adjudicated below (functionally entrypoint-equivalent, mechanically opposite in context cost: ~114KB injected tool spec per session vs zero); (4) official-MCP graduation branch codified with triggers. Agent-degraded log: sparring subagent empty twice on this batch (2026-09-30 late); session total 2 failed-of-4 batches = at the kimi-k3 respawn revert threshold — raise default-model discussion with user.

**Revision 2026-10-01 (execution pass — recon complete, write pass armed):**
- AppImage hash prefetched and pinned: `Anytype-0.57.3.AppImage` → `sha256-8ztoP6O5pZlE3XfNqbnQepDgkAQxCOi41/KFyzXVG3w=` (nix store prefetch, verified).
- Wiring points verified on disk: module import list `hosts/laptop/home.nix:37-108` (ai block ~65-66, app block 90-103); nixpkgs anytype at `hosts/laptop/packages/user.nix:155`; sops registry `modules/user/ai/opencode/secrets.nix` (add `"api_keys/anytype"` there); opencode settings pass-through at `modules/user/ai/opencode/default.nix:28-40` (add `permission` map there as settings keys; HM passes settings through — VERIFY via `nix eval` of the HM config before switching).
- User decisions logged: supermemory plugin update approved (v2.0.13→v2.0.15: `bunx opencode-supermemory@latest install` post-switch, JS runtime present = bun); keep kimi-k3 default despite 50% batch failure (user accepted the overhead; AGENTS.md note relaxed accordingly).
- Mode flipped back to PLAN after the "go" — no implementation files touched yet; this plan is the armed write pass. On mode-exit: execute sections 1-4 + enforcement + Phase 1.5 verbatim, then run Verification.

**Revision 2026-09-30d (anytype 0.57.3 stable upstream; plan-file placement corrected):**
- Verified live: `anytype-ts` **v0.57.3 is the latest stable** (`releases/latest`, `prerelease: false`, published 2026-09-30, deb/AppImage/rpm assets present). Previous blocker "wait for stable 0.57.x" is now SATISFIED upstream — but the user's channel is pinned to 0.56.1 and nixpkgs master is at 0.57.0, so adoption happens via **in-tree pin**, not channel follow.
- **New Phase 1.5 (pin the app, following the repo's actual conventions — verified 2026-10-01):** top-level `pkgs/anytype-57x3/` (pattern: `pkgs/escrcpy`, `pkgs/simpmusic`, `pkgs/supermemory` all use this) + consumer module `modules/user/app/anytype.nix` shipping the official AppImage via `pkgs.appimageTools.wrapType2` (pattern: `modules/user/app/gopeed.nix:5` — the repo already wraps AppImages this way), hash-pinned from the v0.57.3 release assets. Chosen over `overrideAttrs` on the source build (that build couples an offline node_modules mirror + anytype-heart commit: real rehash work). Community flakes rejected on evidence: `hellodword/anytype-flake` stale since 2025-03, `cmars/anytype-nix` stale since 2023-07. Wiring: replace `anytype` in `hosts/laptop/packages/user.nix:155` with the pinned package; **add the AppImage pname to `unfree-list.nix` if its derivation name differs** (mirror how escrcpy is handled there — comment at unfree-list.nix:21 notes eval-time requirements). License unchanged upstream.
- After install, Verification gains: (a) `curl -s http://127.0.0.1:31009/v2/docs/openapi.json` — confirm v2 serves; (b) if yes: probe `/v2` auth/whoami shape for per-key permission grants (does the desktop UI offer scoped keys on 0.57?) — re-answers the MCP-graduation read-only-key question with live truth; (c) wrapper continues to pin `/v1` + `Anytype-Version: 2025-11-08` header FOR THE TRIAL even with v2 present (v1 is the risk-managed surface; v2 availability is a data point for graduation, not an upgrade of the trial — graduating the *sandbox guard* of the client to v2 header with etag/idempotency becomes a separate micro-decision at re-evaluation).
- **Plan-file placement (user correction, second notice):** final spec doc lands tracked as `modules/user/ai/anytype-trial.md` next to the module at execution (promotion step in Deploy); `.opencode/plans/` remains scratch-in-repo only. No `home.file` (read-only store symlink would wedge trial-time updates). Tracked-in-git = the declarative home for a repo-local doc.

## Decisions locked this session
- Integrate Anytype via curl-on-demand trial — NOT anytype-mcp (50 tools / 30 writes always-on = rejected).
- Anytype version: upstream v0.57.3 verified STABLE 2026-09-30 (today) — "wait for stable" condition now satisfied; adoption via in-tree pin (Phase 1.5), no channel-follow, no beta. Graduation to full MCP re-checks v2 read-only keys once the pinned app is running.
- Browser/JS-walled links: lightpanda chosen from 6-candidate review — **explicitly deferred** (not in this plan's scope).
- Context: verdict history — opencode `permission` config (arbitrary tool-name keys, verified in config schema) solves MCP write-scoping at graduation, but not always-on context cost.

## Phase 0 — user actions (cannot be done by the agent)
1. Anytype desktop app → Settings → API Keys → `Create new`.
2. Create the sandbox space for agent writes (suggested name **`AgentLab`**) — agent writes are mechanically confined to it; curated spaces stay read-only for agents.
3. Add the key to the sops-nix secret store (same encrypted source file used by `modules/user/ai/supermemory.nix:174`, new key e.g. `anytype_api_key`). The module renders it to `~/.config/anytype-agent/api-key` (mode 0400) — no plain-text secret anywhere.

## Phase 1 — agent actions (after plan-mode exit)

### 1. Add declarative module `modules/user/ai/anytype.nix` (writeShellScriptBin wrapper)

Precedent (verified 2026-09-30): existing `~/.local/bin/*` entries are home-manager symlinks into `/nix/store/*-home-manager-files`. Module shape:

```nix
{ config, pkgs, ... }:
{
  # secret: add `anytype_api_key` to the same sops source file used by
  # modules/user/ai/supermemory.nix (sops.templates pattern)
  sops.templates."anytype-api-key" = {
    path = "${config.xdg.configHome}/anytype-agent/api-key";
    mode = "0400";
    content = config.sops.placeholder.anytype_api_key;
  };

  # Bootstrap: after first `anytype-cli GET /v1/spaces` (Verification step 3),
  # put the sandbox space's id here and switch again. Empty = writes denied.
  environment.sessionVariables.ANYTYPE_SANDBOX_ID = "";

  home.packages = [
    (pkgs.writeShellScriptBin "anytype" (builtins.readFile ./anytype.sh))
  ];
}
```

with sibling `modules/user/ai/anytype.sh` (file, not inline string — keeps shell quoting clean), body:

```sh
#!/bin/sh
# anytype — thin read-anywhere + sandbox-only-write CLI client over the
# Anytype desktop app's Local API ("curl with rules"; NOT an MCP, not a nix wrap)
# Trial (2026-09-30): every call logged to ${XDG_STATE_HOME:-$HOME/.local/state}/anytype-trial.log
set -eu

BASE="${ANYTYPE_API_BASE:-http://127.0.0.1:31009}"
VER="2025-11-08"
KEY_FILE="${ANYTYPE_API_KEY_FILE:-$HOME/.config/anytype-agent/api-key}"
SANDBOX_ID="${ANYTYPE_SANDBOX_ID:-}"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/anytype-trial.log"

die() { echo "anytype: $*" >&2; exit 2; }

usage="usage: anytype-cli docs | anytype GET /v1/<path> | anytype <POST|PATCH|DELETE> /v1/spaces/$SANDBOX_ID/<path> ['<json>']
rules:  GET anywhere. POST/PATCH/DELETE only inside the sandbox space (ANYTYPE_SANDBOX_ID).
examples:
  anytype-cli GET /v1/spaces
  anytype-cli docs                  # app's OpenAPI spec = endpoint discovery (pipe through jq/head)"

[ $# -ge 1 ] || die "$usage"

if [ ! -f "$KEY_FILE" ]; then
  die "no API key at $KEY_FILE — sops template renders it; run Phase 0 + home-manager switch"
fi

KEY=$(cat "$KEY_FILE")
mkdir -p "$(dirname "$LOG")"

request() { # $1=METHOD $2=path $3=optional body
  if [ -n "${3:-}" ]; then
    curl -sS -m 30 -w '\n%{http_code}' -X "$1" \
      -H "Authorization: Bearer $KEY" -H "Anytype-Version: $VER" \
      -H 'Content-Type: application/json' -d "$3" "$BASE$2"
  else
    curl -sS -m 30 -w '\n%{http_code}' -X "$1" \
      -H "Authorization: Bearer $KEY" -H "Anytype-Version: $VER" \
      -H 'Accept: application/json' "$BASE$2"
  fi
}

run() { # $1=METHOD $2=path $3=optional body
  RESP=$(request "$1" "$2" "${3:-}") || die "cannot reach $BASE — is the Anytype app running?"
  CODE=${RESP##*$'\n'}
  printf '%s\n' "${RESP%$'\n'*}"
  printf '%s %s %s -> %s\n' "$(date -Is)" "$1" "$2" "$CODE" >> "$LOG"
  case "$CODE" in 2*|3*) return 0 ;; *) echo "anytype: HTTP $CODE" >&2; return 1 ;; esac
}

if [ "$1" = docs ]; then
  for p in /v1/docs/openapi.json /docs/openapi.json; do
    if RESP=$(request GET "$p" 2>/dev/null); then
      CODE=${RESP##*$'\n'}
      [ "$CODE" = 200 ] && { printf '%s\n' "${RESP%$'\n'*}"; printf '%s GET %s -> 200\n' "$(date -Is)" "$p" >> "$LOG"; exit 0; }
    fi
  done
  die "cannot fetch OpenAPI spec from $BASE — is Anytype running (and the key valid)?"
fi

[ $# -ge 2 ] || die "$usage"
METHOD=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
case "$METHOD" in GET) ;; POST|PATCH|DELETE)
  [ -n "$SANDBOX_ID" ] || die "writes disabled until ANYTYPE_SANDBOX_ID is set (module bootstrap)"
  case "$2" in
    */spaces/"$SANDBOX_ID"*|*/spaces/"$SANDBOX_ID") ;;   # inside sandbox space
    *) die "non-GET allowed only inside sandbox space $SANDBOX_ID (got: $2)" ;;
  esac ;;
  *) die "invalid method '$1' (GET | POST | PATCH | DELETE)" ;;
esac
if [ "$METHOD" = GET ] || [ "$METHOD" = DELETE ]; then
  run "$METHOD" "$2" ""
else
  [ $# -ge 3 ] || die "$usage"
  run "$METHOD" "$2" "$3"
fi
```

Rationale for design choices (write-scope revision):
- **Sandbox-scoped write is the shape of "full CRUD" here**: user demanded read+write+modify+refactor; v1 offers them all, but with no If-Match/idempotency and Bin as the only undo. One designated space (`ANYTYPE_SANDBOX_ID`) = the agent's scratchpad with full CRUD; curated spaces stay untouchable until the user explicitly widens the guard (one-line module edit).
- **Mechanism-vs-function answer to the "why not the official MCP" charge**: functionally any bridge is an entrypoint; mechanically the official MCP injects ~52 tool specs (~114KB v1) into EVERY session of EVERY model — including the weak tool-callers — while this CLI costs ~0 context (only the ~12-line AGENTS.md entry). Capability is equivalent for the trial's verbs; the wrapper additionally owns the funnel log (trial's measurable judge) and the sandbox guard — both structural, not ask-the-model.
- **Graduation to official MCP is codified, not ruled out** — see "Kill criterion / re-evaluation": triggers are (i) pinned 0.57.3 running with `/v2` confirmed by probe (verified stable upstream 2026-09-30d; in-tree pin in Phase 1.5), (ii) observed spec-vs-wrapper friction in the log (>1/3 failed writes), (iii) MCP tool-cost probe at wiring time (verify whether permission-denied tools still cost context).
- Declarative module + sops-rendered key (0400), zero imperative state — placement and secret-handling both follow user mandates (2026-09-30c).

### 2. Append to `modules/user/ai/opencode/AGENTS.md` (after the "Subagent failure handling" section)

```md
## Artifact placement (hard rule, applies to every session)

- Every artifact an agent produces — plans, scripts, wrappers, docs — lives in nix-config, declaratively (a module under `modules/user/...` or a tracked doc). Never scatter to `~/.local/bin`, `/tmp-survivors`, or editable caches.
- Exceptions: secrets (sops or 600 files outside the flake), runtime state/logs (XDG state dirs), session scratch (/tmp, sandboxes), anything the user explicitly exempts in-session.
- Precedent: existing `~/.local/bin/*` helpers are `writeShellScriptBin` symlinks — follow that pattern.

## Anytype Local API (trial, started 2026-09-30)

- The user's personal knowledge base (Anytype desktop app) is reachable via the `anytype` CLI client (flake-declared) against the app's Local API on `127.0.0.1:31009`. The app must be running; if the client reports it cannot connect, say so — do not retry blindly.
- Rules: `GET` anywhere (reads/search across all spaces). Non-GET (**POST/PATCH/DELETE**) only inside the sandbox space (the guard is in the script, not this text). The client will name the sandbox id when refusing.
- Usage: `anytype-cli GET /v1/spaces`, `anytype-cli GET /v1/<path>`, `anytype-cli POST /v1/spaces/<sandbox-id>/objects '<json>'`, `anytype docs` (app's OpenAPI spec — endpoint discovery; pipe through jq/head to keep output small).
- Do NOT bypass the client with raw curl to :31009 — the client is the trial's measurement funnel; bypass = untracked usage (and the permission layer denies it anyway). If you think you need to bypass, report why instead.
- Key: sops-rendered at `~/.config/anytype-agent/api-key` (0400). Calls logged to `${XDG_STATE_HOME:-~/.local/state}/anytype-trial.log`; kill criterion: no real usage in the log by ~2026-10-31.
- Graduation to the official `@anyproto/anytype-mcp` gates on: `/v2` reachable on the pinned 0.57.3 app (probe at Verification step 8b) + a live probe of MCP tool context cost; key-scope grants re-verified at that time.
```

Why the AGENTS.md entry is load-bearing: without it, future sessions never discover the capability and the trial measures nothing (zero usage would be a false negative). Why the artifact-placement rule is AGENTS.md text AND enforced (below): AGENTS.md is the specification, not enforcement — enforcement lives in permission rules + an audit (both listed under Optional hardening, user decides).

### 3. Deploy

```sh
home-manager switch --flake ~/nix-config#user
```

(`AGENTS.md` is tracked in the repo; dirty-tree edits are honored by the flake. Target confirmed: attr name is `user`. The wrapper lands on PATH via the new module in the same switch. No chmod step — the module emits an executable.)

**Document placement follow-up (user correction 2026-09-30):** this plan file exists at `.opencode/plans/` only because plan mode's permission carve-out allows no other writable path mid-planning. Its durable home is the repo: at execution, promote the final spec to a tracked file beside the module it describes — `modules/user/ai/anytype-trial.md` — and commit it with the module change; the `.opencode/plans/anytype-trial.md` copy is session scratch (delete or expire after promotion). `home.file` was suggested as the deployment vehicle and rejected: it would materialize the doc as a read-only nix-store symlink while the doc is a living artifact updated during the trial, and opencode plans are workspace-scoped scratch, not user-global state. Rule: tracked-in-git = declarative home; `.opencode/plans` = scratch, promoted-or-deleted at execution.

### 4. Verification (verification-before-completion, in order)

1. `anytype` → prints usage, exit 2. (no key needed)
2. `anytype-cli POST /v1/spaces '{}'` → exit 2, sandbox/id refusal — proves the path+method gate fires before any network call. (no key needed)
3. `anytype-cli GET /v1/spaces` BEFORE key exists → clear "no API key" error. (no key needed)
4. After user Phase 0: `anytype-cli GET /v1/spaces` → HTTP 200, JSON space list; log line appears in `${XDG_STATE_HOME:-~/.local/state}/anytype-trial.log`.
5. `anytype-cli docs | head -c 400` → OpenAPI JSON (confirms hint-key path-suffix fallback).
6. One real search (endpoint discovered from `docs`) against a term known to exist in the user's spaces.
7. New opencode session sanity: AGENTS.md section visible in injected context (`/nix/store/*-hm_AGENTS.md` updated after switch).

## Enforcement hardening — APPROVED (user chose "Full stack now", 2026-09-30)

Semantics verified against opencode.ai/docs/permissions (2026-09-30, not assumed): permission keys match tool **input** — `read`/`edit` match file paths, `bash` matches parsed command strings, `webfetch` matches URLs; object-form rules take `~`-expanded path globs with last-match-wins (`*` = any chars, `?` = one); `external_directory` triggers only on paths outside the session cwd, so project-local work is never affected.

1. `programs.opencode.settings.permission` in `modules/user/ai/opencode/default.nix` — add:

```jsonc
"permission": {
  "external_directory": "deny",                                  // scatter stop: no Edit/Write outside cwd
  "bash": {
    "*": "allow",
    "cat*>>*~/.local/bin/*": "deny",  "*>*/.local/bin/*": "deny", // best-effort scatter patterns
    "curl*31009*": "deny"                                        // trial funnel: no raw API curl (see 3)
  }
}
```

   Caveats (owned, not hidden): scatter-path bash patterns are best-effort (shell is unsealable by pattern-matching; `tee`, heredocs, `cp` variants). This is mitigation ceiling with the audit as the real tripwire (see 2).

2. Deterministic audit — new flake app `nix run .#audit-strays`: realpath every entry in `~/.local/bin` (and any future user-bin dirs), flag anything not resolving to `/nix/store/*-home-manager-files`. Add also `${XDG_STATE_HOME:-~/.local/state}` is NOT audited (logs live there legitimately), and `~/.config/anytype-agent/` is whitelisted (secret file). Verified precedent on this machine: all 4 current `~/.local/bin` entries already resolve into the nix store.

3. **Trial-integrity rule (new, follows from the verified semantics):** `bash` deny of `curl*31009*` makes the measurement funnel enforceable — direct raw-curl against the Anytype API is denied; the `anytype` wrapper's *internal* curl is invisible to the rule (permissions match the command opencode executes, i.e. `anytype-cli ...`, not its child processes). This is the falsifier-protection the sparring verdict asked for: answers-from-Anytype-without-log-lines become structurally impossible rather than discipline-dependent.

## Kill criterion / re-evaluation
- ~2026-10-31: read `${XDG_STATE_HOME:-~/.local/state}/anytype-trial.log`. Zero/near-zero real usage → remove module + AGENTS.md sections (revert, re-switch) — the capability was theoretical.
- Real usage → graduation discussed then: official `@anyproto/anytype-mcp` wiring (global + permission-gated, or attached to a dedicated subagent via AgentConfig.tools) with live checks first: (i) runtime MCP tool names, (ii) whether permission-denied tools still occupy context (schema says permission gates execution; context-cost of denial unverified), (iii) Anytype stable 0.57 → `/v2` probe + scoped/read-only key grants on the developer portal, (iv) v2 etag/idempotency benefits justify the context tax vs the CLI client staying.
## Explicitly out of scope (recorded, not forgotten)

- **lightpanda `webread` wrapper** (deferred by user vote). Revised post-sparring design: ONE wrapper `webread` exposing both text and pixel paths — `lightpanda fetch --dump markdown <url>` AND `lightpanda fetch --dump png > out.png` (png → the agent's read tool accepts images directly; vision-capable chat models already exist in the user's setup — this covers "visual content" without PixelRAG's infra). Log typed events: **E1** (markdown insufficient → png+vision rescued) and **E2** (engine wall-failure → page didn't render). E1 recurring ≥ ~25% of fetches → PixelRAG earns a *sequential* second trial; E2 recurring → graduate the renderer layer to Chromium fidelity instead: **`brave --headless --screenshot|--dump-dom`** (Brave already installed — zero new packages, same wrapped/auditable architecture). Gating test for the trial start: `lightpanda fetch --dump markdown <one real share.google/aimode link>` renders the conversation → proceed.
- **PixelRAG reconsideration (user challenged my REJECT, 2026-09-30):** verdict — the user's "different solution to the same base problem" is HALF-RIGHT at renderer layer (pixelshot's real Chromium vs lightpanda's Zig engine = real fidelity gap, conceded; but Chromium fidelity is obtainable at zero infra via installed Brave headless), and the pixelstore's actual surplus (corpus-scale visual retrieval via Qwen3-VL-Embedding-2B index) is unreachable at their frequency (few pages/week → no corpus forms → retrieval machinery never amortizes). "Run both alongside and compare" rejected on methodology: a corpus-retrieval system measured on a one-shot workload produces a false negative with double infra (the same contaminated-measurement trap the user's own local-llm v5 protocol gates against: frozen window, single judge, live data only). Path forward = the E1/E2 design above; if it fires, package pixelrag as a flake module (python env + pixelshot + poppler pin) — never pip-side-effects in the wild.
- **Declarative-artifacts enforcement** — see "Optional enforcement hardening" above (user decision pending).
- **Anytype version decoupling from nixpkgs channel** (user voted: wait for stable 0.57.x).
- **firecrawl (user-added candidate, 2026-09-30):** 187k★, TypeScript, AGPL-3. Facts: self-host = docker-compose stack (api + worker + redis + playwright-service — repo ships `docker-compose.yaml` + `SELF_HOST.md`); no docker on this machine; cloud tier is a paid SaaS (api.firecrawl.dev + `fc-` keys). Genuinely strong endpoints (scrape/crawl/map/batch/search) — but for the JTBD ("occasionally render one JS-walled link → text") it is the heaviest shape evaluated: a distributed service where a 60-line command suffices. Verdict: recorded on the deferred shelf with a specific trigger — adopt when/if a *bulk crawl/map* need appears (whole-site ingestion, thousands of URLs — the one job lightpanda/Brave legitimately cannot do); at that point it becomes a flake-packaging project (native node + playwright-service, no docker dependency). Not in current execution scope.
- playwright MCP / Scrapling / BrowserSkill / browser-use / jev-ultrafast — rejected 2026-09-30 source-verified sparring round; analysis archived in context-mode knowledge base (source labels `cand-*`). BrowserSkill (agent rides real logged-in browser): rejected on session-inheritance risk for this JTBD; re-open only as a dedicated login-free profile discussion if a future task truly needs authenticated scraping — even then, the value prop mostly evaporates without logins.

---

## EXECUTION RECORD (2026-10-02, home-manager switch successful)

- Module deployed: `modules/user/ai/anytype.nix` + `anytype.sh`; client on PATH as `anytype-cli`; sops renders key to `~/.config/anytype-agent/api-key` (verified symlink to sops-nix rendered secret, 0600).
- App pinned: 0.57.3 AppImage via `modules/user/app/anytype.nix`; runs as `anytype` (renamed from anytype-desktop 2026-10-03) (unrun until user restarts Anytype — process on screen is still 0.56.1 channel build).
- opencode.json regenerated: `permission.external_directory=deny`, bash funnel patterns (`*>*/.local/bin/*` deny, `curl*127.0.0.1:31009*` deny) verified in rendered JSON; supermemory plugin pinned to 2.0.15 (this WAS the "update Supermemory" ask — nix pin replaces the bunx path since config is store-managed; takes effect at next opencode start).
- `nix run .#audit-strays` → OK (all `~/.local/bin/*` resolve into /nix/store). Initial false-positives fixed by generalizing the resolver test.
- Live trial evidence: `anytype-cli GET /v1/spaces` → 200, JSON with 10 spaces; log line written to `~/.local/state/anytype-trial.log`. Sandbox gate refused POST without sandbox id — exactly as specified.
- REMAINING (user-side): (a) create the `AgentLab` space in the app, (b) restart Anytype to run 0.57.3, then (c) tell the agent — bootstrap sets ANYTYPE_SANDBOX_ID in the module and re-switches; then `/v2` probe on the running pinned app.

## HOTFIX RECORD (2026-10-02, after 0.57.3 switch)

- Upgrading the app to 0.57.3 invalidated the previously issued flat key (401 invalid on ALL routes incl. v1/spaces). Old gen1 (unscoped) key died with the old generation.
- New key ("agent") confirms the v2 scoped-grant model is REAL: /v2/auth/whoami → {"scope":"jsonApi","grant":{"scoped":true,"restricted":true,"all_spaces":false,"permission":"readwrite","spaces":[{"id":"dlfy44","name":"AgentLab"}]}}. The 2026-09-30 docs-day claim "scoped/read-only keys exist in v2" is now VERIFIED TRUE live (yesterday doc said unproven; the pinned app answered).
- Scoped keys REFUSE /v1 (403 v1_not_available_for_scoped_keys) → wrapper defaults flipped to /v2 (usage text + docs probing order). Guard kept: path whitelist still contains-one-space.
- Sandbox id re-captured after upgrade (bafyreihse…dlfy44.392c4s40nba6c) — space ids are regenerated across installs; bootstrap note in module updated accordingly.

## RENAME RECORD (2026-10-03)

- Name swap after user report (session ses_f2fb3baa surfaced it): typing `anytype` produced the CLI usage text — the trial client had stolen the GUI name. Swap: GUI binary back to `anytype` (wrapType2 pname), agent client now `anytype-cli` (writeShellScriptBin + usage text + AGENTS.md + this doc). Log path, key path, gates, sandbox id unchanged.
- Also this date: worktree drift from 2026-10-02 14:50 (4 files reverted to pre-hotfix state by an external bulk restore) was reconciled via `git restore` to HEAD — the verified v2/scoped-key state; drift evidence in git reflog if needed.
