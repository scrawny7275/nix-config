# modules/user/devtools/scala-toolchain/metals-repair.nix
#
# Declarative, client-agnostic Metals auto-repair.
#
# Why this exists:
#   Metals gets stuck in two distinct ways:
#   1. Compile-polling loop: 60s `Processing buildTarget/compile` with zero
#      `time: compiled`, plus `pool-*-thread InterruptedException` and
#      `Unmatched cancel notification` storms. Fix: scoped repair (kill,
#      wipe derived dirs, reseed, reimport).
#   2. DNS/proxy failure: `UnknownHostException` / `Failed to resolve
#      ... presentation compiler` (off-VPN nexus NXDOMAIN). The PC never
#      resolves, no build targets attach, LSP degrades — but there is no
#      compile loop, so the stall detector stays quiet. Fix: check
#      VPN/proxy, then restart the client. Reseed does NOT fix it (the
#      cache is already seeded); `status` reports the cause so you don't
#      waste a repair on a network outage.
#   3. Coursier 0% download spin: repeated `(0.00 %, 0 / N)` progress
#      lines in metals.log — JVM stuck fetching an artifact that curl
#      can reach (stale unlocked *.lock / *.part from a crashed import,
#      or no read timeout on a black-holed connection). The loop writes
#      a fresh ERROR every few seconds, so check_stuck_duration (keyed
#      on last-ERROR age) NEVER fires; detection keys on zero-progress
#      line count instead. Fix: hard repair (kill wedged JVMs, sweep
#      unlocked cache locks/partials + orphan .checked markers).
#
# Auto-repair (when enabled via devtools.scala.repair.autoRepair):
#   The weekly timer runs `check-and-repair` instead of bare reseed.
#   For each discovered project it runs `status_one()` and:
#     GREEN/GRAY — skip.
#     YELLOW — reseed cache only (safe, idempotent).
#     RED — auto-repair if:
#       a) last ERROR in metals.log is > autoRepairAfter minutes ago
#          (avoids false positives during brief VPN transitions), AND
#       b) no cooldown marker for this project (cooldown = autoRepairCooldown
#          minutes since last auto-repair, prevents repair loops).
#   Cooldown state lives in ~/.cache/metals-repair/.auto-repair-{hash}.
#
# Safety contract:
#   - Timer runs check-and-repair (reseed + status + conditional auto-repair).
#     Auto-repair only triggers when RED for >N minutes with clear cooldown.
#   - Full manual `repair` is always available via
#     `systemctl --user start metals-repair-<proj>`.
#     Deletes are allowlisted to derived dirs under an explicit project dir
#     containing `build.sbt`; `$HOME` itself and `/` are refused;
#     `.bsp/sbt.json` is preserved.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.devtools.scala;
  rcfg = config.devtools.scala.repair;

  metalsCache = "${config.xdg.cacheHome}/metals-coursier/v1";
  jdk = config.devtools.java.selectedJdk;

  # Same multi-repo-key layout as metals-wrapper.nix (kept in sync by hand;
  # wrapper owns the switch-time seed, this module owns on-demand repair).
  pcDeps = pkgs.callPackage ./metals-pc-deps.nix {
    inherit (config.modules.private.values) nexusMirrorKeys;
  };
  pcCacheLayout = pkgs.runCommand "metals-pc-cache-layout" { } ''
    mkdir -p "$out/v1/https"
    for repoKey in \
      "repo1.maven.org/maven2" \
      ${lib.concatMapStringsSep " \\\n      " lib.escapeShellArg config.modules.private.values.nexusMirrorKeys} \
      "central.sonatype.com/repository/maven-snapshots"; do
      mkdir -p "$out/v1/https/$repoKey"
      cp -a "${pcDeps}/v1/https/repo1.maven.org/maven2/." \
        "$out/v1/https/$repoKey/"
    done
    chmod -R u+rwX "$out/v1"
  '';

  baseOf = dir: baseNameOf (builtins.toString dir);
  svcOf = dir: "metals-repair-${lib.replaceStrings [ "." " " ] [ "-" "-" ] (baseOf dir)}";

  repairBin = pkgs.writeShellScriptBin "metals-repair" ''
    set -euo pipefail
    BAKED_PROJECTS=${lib.escapeShellArg (lib.concatStringsSep ":" rcfg.projects)}
    AUTO_DISCOVER=${if rcfg.autoDiscover then "1" else "0"}
    IDEA_ROOT="$HOME/IdeaProjects"
    METALS_CACHE=${lib.escapeShellArg metalsCache}
    PC_LAYOUT=${lib.escapeShellArg "${pcCacheLayout}/v1"}
    GC_TTL=${lib.escapeShellArg rcfg.cacheGcTtl}
    JDK_BIN=${lib.escapeShellArg "${jdk}/bin/jar"}
    CS_BIN=${lib.escapeShellArg "${pkgs.coursier}/bin/cs"}
    AUTO_REPAIR=${if rcfg.autoRepair then "1" else "0"}
    AUTO_REPAIR_AFTER=${toString rcfg.autoRepairAfter}
    AUTO_REPAIR_COOLDOWN=${toString rcfg.autoRepairCooldown}
    COOLDOWN_DIR="${config.xdg.cacheHome}/metals-repair"

    expand_dir() {
      case "$1" in
        "~"/*) printf '%s/%s' "$HOME" "''${1#"~/"}";;
        "~") printf '%s' "$HOME";;
        *) printf '%s' "$1";;
      esac
    }

    discover_projects() {
      declare -A seen=()
      local p d
      IFS=':' read -ra _baked <<< "$BAKED_PROJECTS"
      for p in "''${_baked[@]}"; do
        [ -n "$p" ] || continue
        d=$(expand_dir "$p")
        if [ -z "''${seen[$d]:-}" ]; then seen[$d]=1; printf '%s\n' "$d"; fi
      done
      if [ "$AUTO_DISCOVER" = "1" ] && [ -d "$IDEA_ROOT" ]; then
        for d in "$IDEA_ROOT"/*/; do
          [ -f "$d/build.sbt" ] || continue
          d=''${d%/}
          if [ -z "''${seen[$d]:-}" ]; then seen[$d]=1; printf '%s\n' "$d"; fi
        done
      fi
      # Live instances: any metals/sbt cwd holding a build.sbt joins the set.
      # Matches: Metals main, BSP sbt processes, AND stale sbt background
      # daemons (--detach-stdio) — any sbt-launch process for this project.
      local pid cwd
      for pid in $(pgrep -f 'scala.meta.metals.Main|sbt-launch\.jar' 2>/dev/null || true); do
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
        if [ -n "$cwd" ] && [ -f "$cwd/build.sbt" ] && [ -z "''${seen[$cwd]:-}" ]; then
          seen[$cwd]=1; printf '%s\n' "$cwd"
        fi
      done
    }

    guard_dir() {
      local d=$1
      [ -n "$d" ] || { echo "metals-repair: empty project dir" >&2; return 1; }
      [ "$d" != "/" ] || { echo "metals-repair: refusing /" >&2; return 1; }
      [ "$d" != "$HOME" ] || { echo "metals-repair: refusing \$HOME itself" >&2; return 1; }
      case "$d" in "$HOME"/*) ;; *) echo "metals-repair: refusing outside \$HOME: $d" >&2; return 1;; esac
      [ -f "$d/build.sbt" ] || { echo "metals-repair: no build.sbt in $d" >&2; return 1; }
    }

    pids_with_cwd() { # <pattern> <dir> -> pids (may be empty)
      local pat=$1 dir=$2 pid cwd
      for pid in $(pgrep -f "$pat" 2>/dev/null || true); do
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
        [ "$cwd" = "$dir" ] && printf '%s\n' "$pid"
      done
      return 0
    }

    # Like pids_with_cwd but also filters by minimum age in minutes.
    # Uses `etimes` (elapsed seconds) — NEVER parse `etime`: processes
    # under one hour print MM:SS which a naive HH:MM parser misreads,
    # silently making every age gate fire at ~1 min (live bug, fixed).
    pids_with_cwd_aged() { # <pattern> <dir> <min_minutes> -> pids
      local pat=$1 dir=$2 min_age=$3 pid cwd esec
      for pid in $(pgrep -f "$pat" 2>/dev/null || true); do
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
        [ "$cwd" = "$dir" ] || continue
        esec=$(ps -o etimes= -p "$pid" 2>/dev/null | xargs || true)
        [ -n "$esec" ] || continue
        [ "$esec" -ge "$((min_age * 60))" ] && printf '%s\n' "$pid"
      done
      return 0
    }

    status_one() { # <dir> -> green|yellow|red line, exit 0|1|2
      local d=$1 log tail_n=300 proc comp canc intr dns pc_fail notarget last_comp dl0 live_metals dl0_recent_cutoff
      guard_dir "$d" >/dev/null 2>&1 || { echo "SKIP $d (guard)"; return 3; }
      log="$d/.metals/metals.log"
      [ -f "$log" ] || { echo "GRAY $d (no metals.log yet)"; return 3; }
      tail_n=300
      proc=$(tail -n $tail_n "$log" | grep -c 'Processing buildTarget' || true)
      comp=$(tail -n $tail_n "$log" | grep -c 'time: compiled' || true)
      canc=$(tail -n $tail_n "$log" | grep -c 'Unmatched cancel notification' || true)
      intr=$(tail -n $tail_n "$log" | grep -c 'InterruptedException' || true)
      # Failure mode 3: zero-progress coursier downloads. A healthy slow
      # transfer shows a non-zero %; (0.00 %, 0 / N) repeating means the
      # fetch got 0 bytes (stale lock / hung socket). Only count lines
      # from the last 15 minutes — metals.log is append-only, so a
      # reopened client would otherwise inherit the previous session's
      # stall lines and false-RED a healthy JVM. A live stall mints a
      # fresh line every few seconds, so the recent window still catches it.
      dl0_recent_cutoff=$(date -d '15 minutes ago' '+%Y.%m.%d %H:%M' 2>/dev/null || echo '0000.00.00 00:00')
      # Anchor to a real leading timestamp so stack-trace continuation
      # lines (no date prefix) cannot compare "greater" than the cutoff.
      dl0=$(grep '0\.00 %, 0 /' "$log" 2>/dev/null \
        | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]{2} ' \
        | awk -v c="$dl0_recent_cutoff" 'substr($0, 1, 16) >= c' \
        | wc -l | xargs)
      # Network failure mode: DNS timeout / nexus unreachable / PC fetch
      # failed. Same recency filter — old VPN blips must not red-flag a
      # fresh session. Fix when live: check VPN/proxy, then restart client.
      dns=$(grep -E 'UnknownHostException|ConnectException|SocketTimeoutException' "$log" 2>/dev/null \
        | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]{2} ' \
        | awk -v c="$dl0_recent_cutoff" 'substr($0, 1, 16) >= c' \
        | wc -l | xargs)
      pc_fail=$(grep -E 'Failed to resolve Scala.*presentation compiler|Error downloading Dependency.*presentation-compiler' "$log" 2>/dev/null \
        | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]{2} ' \
        | awk -v c="$dl0_recent_cutoff" 'substr($0, 1, 16) >= c' \
        | wc -l | xargs)
      notarget=$(tail -n $tail_n "$log" | grep -c 'no build target' || true)
      last_comp=$(grep 'time: compiled' "$log" | tail -1 | cut -c1-19 || true)
      # Live metals process for this project (empty if client closed /
      # post-repair). RED/YELLOW log patterns are only actionable when
      # a JVM is actually wedged — otherwise they are historical and the
      # timer must not re-repair an already-clean project.
      live_metals=$(pids_with_cwd 'scala.meta.metals.Main' "$d" 2>/dev/null | head -1 || true)
      if [ -z "$live_metals" ]; then
        if [ "$dl0" -ge 10 ]; then
          echo "GRAY $d (metals not running; historical download_stall=$dl0 — reopen client to restart LSP)"
        elif [ "$dns" -gt 0 ] || [ "$pc_fail" -gt 0 ]; then
          echo "GRAY $d (metals not running; historical DNS/proxy=$dns pc_fail=$pc_fail — reopen client)"
        elif [ "$proc" -ge 3 ] && [ "$comp" -eq 0 ]; then
          echo "GRAY $d (metals not running; historical processing=$proc — reopen client)"
        else
          echo "GRAY $d (metals not running; reopen client to start LSP)"
        fi
        return 3
      fi
      if [ "$dl0" -ge 10 ]; then
        echo "RED $d (download_stall=$dl0; coursier stuck at 0 bytes — stale cache locks or hung socket; hard repair sweeps locks + restarts JVMs)"
        return 2
      elif [ "$dns" -gt 0 ] || [ "$pc_fail" -gt 0 ]; then
        echo "RED $d (DNS/proxy: unknown_host=$dns pc_fail=$pc_fail no_target=$notarget last_compile=''${last_comp:-never}; check VPN/proxy, then restart client)"
        return 2
      elif [ "$proc" -ge 3 ] && [ "$comp" -eq 0 ] && [ "$canc" -ge 3 ]; then
        echo "RED $d (processing=$proc compiled=0 cancels=$canc interrupts=$intr last_compile=''${last_comp:-never})"
        return 2
      elif [ "$canc" -gt 0 ] || [ "$intr" -gt 0 ] || [ "$notarget" -gt 5 ]; then
        echo "YELLOW $d (processing=$proc compiled=$comp cancels=$canc interrupts=$intr no_target=$notarget last_compile=''${last_comp:-never})"
        return 1
      else
        echo "GREEN $d (processing=$proc compiled=$comp last_compile=''${last_comp:-never})"
        return 0
      fi
    }

    reseed_cache() {
      local target="$METALS_CACHE" src="$PC_LAYOUT" cc defcc
      if [ -e "$target" ]; then chmod -R u+rwX "$target" || true; fi
      mkdir -p "$target"
      cp -r "$src/." "$target/"
      chmod -R u+rwX "$target"
      # Coursier TTL is measured from each cached artifact's file mtime,
      # and downloaded artifacts carry the upstream Last-Modified date —
      # our seed jars are stamped mid-2025, so the 720h TTL window on the
      # FILES has long expired. That makes every fresh JVM start hit the
      # network for online revalidation, which under a flapping network
      # becomes a multi-minute error storm (observed 2026-10-05: ~850
      # pc_fail errors 10:56-11:14, self-terminated when the network
      # settled). Restart the TTL window on every reseed by touching the
      # seeded trees.
      find "$target" -type f -exec touch {} + 2>/dev/null || true
      # Same default-cache seed as metals-wrapper.nix (kept in sync by
      # hand): sbt resolves PC/compiler deps through its own coursier on
      # the default cache, so the pinned set must live there too for
      # off-VPN resolution. Merge only, never delete.
      defcc="$HOME/.cache/coursier/v1/https/repo1.maven.org/maven2"
      if [ -d "$HOME/.cache/coursier/v1/https" ] && [ -d "$src/https/repo1.maven.org/maven2" ]; then
        mkdir -p "$defcc"
        cp -r "$src/https/repo1.maven.org/maven2/." "$defcc/"
        chmod -R u+rwX "$defcc"
        find "$defcc" -type f -exec touch {} + 2>/dev/null || true
      fi
      cc="$HOME/.cache/coursier/v1/https"
      if [ -d "$cc" ]; then
        find "$cc" -type f -name '*.jar' \
          \( -path '*/org/scala-lang/*' -o -path '*/org/scalameta/*' \) \
          ! -name '*-sources.jar' ! -name '*-javadoc.jar' -print0 |
        while IFS= read -r -d "" jarfile; do
          if ! "$JDK_BIN" tf "$jarfile" >/dev/null 2>&1; then
            echo "metals-repair: corrupt jar removed: $jarfile" >&2
            rm -f "$jarfile" "$jarfile.sha1" "$jarfile.lock" \
              "$(dirname "$jarfile")/.$(basename "$jarfile").checked" \
              "$(dirname "$jarfile")/.$(basename "$jarfile")__sha1" \
              "$(dirname "$jarfile")/.$(basename "$jarfile")__sha1.computed"
          fi
        done
      fi
      # NOTE: `cs gc --ttl` silently no-ops in coursier 2.1.24 (prints the
      # generic usage block, not a gc run) — don't mistake its output for a
      # real GC; the sweep above plus the pinned reseed is what keeps this
      # cache clean. Left in place intentionally quiet for forward-compat
      # once coursier exposes real gc again.
      if [ -x "$CS_BIN" ]; then
        env -u COURSIER_CACHE "$CS_BIN" gc --ttl "$GC_TTL" >/dev/null 2>&1 || true
      fi
      echo "metals-repair: cache reseeded at $target"
    }

    # Snapshot of paths currently open by any JVM (readlink of every
    # /proc/<java-pid>/fd). Used to avoid deleting coursier locks/partials
    # a live process still holds — unlocked leftovers from crashes are
    # fair game. Only scan `java`: metals/sbt/bloop/coursier are all JVMs,
    # and walking every system fd costs ~20s+ (blew TimeoutStartSec once).
    open_fd_list() {
      local pid fd
      for pid in $(pgrep -x java 2>/dev/null || true); do
        for fd in "/proc/$pid"/fd/*; do
          readlink "$fd" 2>/dev/null || true
        done
      done | sort -u
    }

    # Failure-mode-3 sweep: remove *.lock / *.part files nothing holds
    # open, plus orphan .checked markers whose artifact is gone (they
    # make coursier think a fetch completed and then fail the open,
    # re-entering the 0% spin). Age-gate on .part only — a lock with no
    # open fd is stale by definition (kernel releases locks on exit).
    sweep_coursier_cache() { # <root> <dry>
      local root=$1 dry=''${2:-0} f art nlock=0 npart=0 nchk=0 open
      [ -d "$root" ] || return 0
      open=$(open_fd_list)
      while IFS= read -r -d "" f; do
        grep -qxF "$f" <<<"$open" && continue
        if [ "$dry" = 1 ]; then echo "would rm stale lock $f"; else rm -f "$f"; nlock=$((nlock + 1)); fi
      done < <(find "$root" \( -name '*.lock' -o -name '*.part.lock' \) -print0 2>/dev/null)
      while IFS= read -r -d "" f; do
        grep -qxF "$f" <<<"$open" && continue
        find "$f" -mmin +15 -print -quit 2>/dev/null | grep -q . || continue
        if [ "$dry" = 1 ]; then echo "would rm stale partial $f"; else rm -f "$f"; npart=$((npart + 1)); fi
      done < <(find "$root" -name '*.part' -print0 2>/dev/null)
      while IFS= read -r -d "" f; do
        art="$(dirname "$f")/$(basename "$f" | sed 's/^\.//; s/\.checked$//')"
        [ -f "$art" ] && continue
        if [ "$dry" = 1 ]; then echo "would rm orphan .checked $f"; else rm -f "$f"; nchk=$((nchk + 1)); fi
      done < <(find "$root" -name '*.checked' -print0 2>/dev/null)
      if [ "$nlock" -gt 0 ] || [ "$npart" -gt 0 ] || [ "$nchk" -gt 0 ]; then
        echo "metals-repair: cache sweep $root (locks=$nlock partials=$npart orphan_checked=$nchk)"
      fi
    }

    # Check cooldown: returns 0 if cooldown expired (or no marker), 1 if still active.
    check_cooldown() { # <project-dir>
      local d=$1 marker
      marker="$COOLDOWN_DIR/.auto-repair-$(echo "$d" | md5sum | cut -c1-12)"
      [ ! -f "$marker" ] && return 0
      find "$marker" -mmin +"$AUTO_REPAIR_COOLDOWN" -print -quit 2>/dev/null | grep -q . && return 0
      return 1
    }

    # Touch cooldown marker for a project.
    touch_cooldown() { # <project-dir>
      local d=$1 marker
      mkdir -p "$COOLDOWN_DIR"
      marker="$COOLDOWN_DIR/.auto-repair-$(echo "$d" | md5sum | cut -c1-12)"
      touch "$marker"
    }

    # ---- Crash-loop guard ----------------------------------------------
    # Counts auto-repairs per project; >2 in a rolling hour → freeze that
    # project for 2h. Prevents repair → restart → re-fail cascades from
    # looping forever at cooldown pace.
    repair_frozen() { # <project-dir> -> 0 frozen, 1 okay
      local d=$1 marker
      marker="$COOLDOWN_DIR/.repair-frozen-$(echo "$d" | md5sum | cut -c1-12)"
      [ ! -f "$marker" ] && return 1
      find "$marker" -mmin +120 -print -quit 2>/dev/null | grep -q . && { rm -f "$marker"; return 1; }
      return 0
    }

    record_repair() { # <project-dir>; prints "frozen" if this tripped the guard
      local d=$1 log now cutoff count marker
      mkdir -p "$COOLDOWN_DIR"
      log="$COOLDOWN_DIR/.repair-log-$(echo "$d" | md5sum | cut -c1-12)"
      now=$(date +%s)
      cutoff=$((now - 3600))
      [ -f "$log" ] && awk -v c="$cutoff" '$1 >= c' "$log" > "$log.tmp" && mv "$log.tmp" "$log" || true
      echo "$now" >> "$log"
      count=$(wc -l < "$log" | xargs)
      if [ "$count" -ge 3 ]; then
        marker="$COOLDOWN_DIR/.repair-frozen-$(echo "$d" | md5sum | cut -c1-12)"
        touch "$marker"
        echo "metals-repair: AUTO-REPAIR FROZEN for $d ($count repairs in 60min — probable crash loop; frozen 2h. Manual: systemctl --user start metals-repair-$(basename "$d" | tr -c 'a-zA-Z0-9_.' '-'))"
      fi
    }

    # ---- Orphan reaper (failure mode 4: Metals' coursier fallback) -----
    # Metals spawns `cs fetch` CLI children when its embedded coursier
    # fails. Those run with cwd=$HOME (invisible to every project-cwd
    # matcher) and survive Metals' death — observed live: a 15h
    # `cs fetch` orphan holding *.jar.lock flocks in the seeded cache,
    # poisoning the NEXT metals start. Reap only with ALL FIVE conditions:
    reap_orphans() {
      local pid ppid tty age fd hit systemd_pid uid_num
      uid_num=$(id -u)
      systemd_pid=$(pgrep -u "$uid_num" -x systemd | head -1 || echo 1)
      for pid in $(pgrep -f '\.cs-wrapped|sbt-launch\.jar|scala\.meta\.metals' 2>/dev/null || true); do
        # 1. same uid
        [ "$(ps -o uid= -p "$pid" 2>/dev/null | xargs || echo '?')" = "$uid_num" ] || continue
        # 2. parent DEAD: reparented to init or the systemd --user manager
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | xargs || echo '?')
        [ "$ppid" = "1" ] || [ "$ppid" = "$systemd_pid" ] || continue
        # 3. no controlling TTY (user's interactive sbt/cs has one)
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | xargs || echo '?')
        [ "$tty" = "?" ] || continue
        # 4. old enough to not race a legit fresh launch
        age=$(ps -o etimes= -p "$pid" 2>/dev/null | xargs || echo 0)
        [ "$age" -ge "$((AUTO_REPAIR_AFTER * 60))" ] || continue
        # 5. corroboration: holds an fd inside a coursier cache
        hit=0
        for fd in /proc/"$pid"/fd/*; do
          case "$(readlink "$fd" 2>/dev/null || echo none)" in
            "$METALS_CACHE"/*|"$HOME"/.cache/coursier/v1/*) hit=1; break;;
          esac
        done
        [ "$hit" = 1 ] || continue
        echo "metals-repair: reaping orphaned metals child pid $pid (age $((age / 60))min, holds cache fd) — parent died"
        kill "$pid" 2>/dev/null || true
      done
      # Scope-native orphan sweep: a scope for this project with no live
      # scala.meta.metals.Main inside is orphaned BY DEFINITION — every
      # process still in it (coursier fallback children incl. reparented
      # ones) dies with the unit. Exact, no heuristics.
      if command -v systemctl >/dev/null 2>&1; then
        local unit cg member has_main
        for unit in $(systemctl --user list-units --all --no-legend 'metals-*.scope' 2>/dev/null \
            | awk '{print $1}' | grep -E '^metals-.+\.scope$' || true); do
          cg=$(systemctl --user show -p ControlGroup --value "$unit" 2>/dev/null || echo none)
          [ -n "$cg" ] && [ "$cg" != "none" ] || continue
          has_main=0
          for member in $(systemd-cgls --no-pager "$cg" 2>/dev/null \
              | grep -oP '[0-9]+(?= )' | head -20 || true); do
            if grep -q 'scala.meta.metals.Main' "/proc/$member/cmdline" 2>/dev/null; then has_main=1; break; fi
          done
          if [ "$has_main" = 0 ]; then
            echo "metals-repair: reaping orphaned scope $unit (no metals JVM inside — wholesale teardown)"
            systemctl --user kill --kill-whom=all "$unit" 2>/dev/null || true
          fi
        done
      fi
      return 0
    }

    # ---- Automatic LSP reattach -----------------------------------------
    # Zed does not auto-restart a dead language server, and --pipe scopes
    # don't fix that. CHANNEL: Zed watches project .zed/settings.json and
    # restarts an LSP server when its initialization_options change (init
    # options require a restart to apply, per LSP). We bump a tick key.
    # SAFE RULE: create the file only when .zed/settings.json doesn't
    # exist, or update only when we own a marker key already — never
    # clobber a hand-written project settings file.
    nudge_lsp_reattach() { # <project-dir>
      local d=$1 zf stamp
      zf="$d/.zed/settings.json"
      stamp=$(date +%s)
      if [ -f "$zf" ] && ! grep -q '"_healTick"' "$zf" 2>/dev/null; then
        echo "metals-repair: $zf exists and isn't ours — not touching. Run 'editor: restart language server' in the client."
        return 0
      fi
      if [ -f "$zf" ]; then
        sed -i "s/\"_healTick\": *[0-9]*/\"_healTick\": $stamp/" "$zf"
        echo "metals-repair: nudged $zf (tick=$stamp) — client restarts the metals LSP"
      else
        mkdir -p "$d/.zed"
        cat > "$zf" <<EOF
{
  "lsp": {
    "metals": {
      "initialization_options": {
        "_healTick": $stamp
      }
    }
  }
}
EOF
        echo "metals-repair: created $zf (tick=$stamp) — client restarts the metals LSP"
      fi
      command -v notify-send >/dev/null 2>&1 && \
        notify-send -a metals-repair -t 8000 "Metals healed" "$(basename "$d"): backend repaired, LSP restarting…" || true
      return 0
    }

    # Check how long ago the last error was logged. Outputs minutes since
    # last ERROR in the log. Returns 0 if > autoRepairAfter, 1 otherwise.
    check_stuck_duration() { # <project-dir>
      local d=$1 log last_err_ts now_ts diff_min
      log="$d/.metals/metals.log"
      [ -f "$log" ] || return 1
      # Get the timestamp of the last ERROR line (format: 2026.09.22 19:46:32)
      last_err_ts=$(grep ' ERROR ' "$log" | tail -1 | cut -c1-19 || true)
      [ -n "$last_err_ts" ] || return 1
      # Convert to epoch (handle NixOS date format)
      now_ts=$(date +%s)
      # Parse: 2026.09.22 19:46:32 → 2026-09-22 19:46:32
      last_err_ts=$(echo "$last_err_ts" | sed 's/\./-/g')
      diff_min=$(( (now_ts - $(date -d "$last_err_ts" +%s 2>/dev/null || echo "$now_ts")) / 60 ))
      [ "$diff_min" -ge "$AUTO_REPAIR_AFTER" ] && return 0
      return 1
    }

    # Nudge rate-limit: one forced LSP restart per project per cooldown
    # window, so a crash-looping server isn't restarted every 10 min.
    check_nudge_cooldown() { # <project-dir> -> 0 okay to nudge
      local d=$1 marker
      marker="$COOLDOWN_DIR/.nudge-$(echo "$d" | md5sum | cut -c1-12)"
      [ ! -f "$marker" ] && return 0
      find "$marker" -mmin +"$AUTO_REPAIR_COOLDOWN" -print -quit 2>/dev/null | grep -q . && return 0
      return 1
    }
    touch_nudge_cooldown() { touch "$COOLDOWN_DIR/.nudge-$(echo "$1" | md5sum | cut -c1-12)"; }

    # Failure mode 6 repair: metals JVM alive but BSP never connected (or
    # gave up after initialize timeouts during a DNS flap) and NO sbt
    # process exists at all. The stale-sbt gate cannot fire (nothing to
    # kill), soft repair is a no-op, and metals never retries on its own.
    # Solution: ask the running server to reconnect via its HTTP command
    # endpoint (isHttpEnabled=true in initialization_options). Cheapest
    # possible fix: zero kills, no reimport cost if it works.
    bsp_reconnect() { # <project-dir> -> 0 reconnect request accepted
      local d=$1 log port
      log="$d/.metals/metals.log"
      [ -f "$log" ] || return 1
      # Port from the most recent "Started Metals http server" line.
      port=$(metals_http_port "$d")
      if [ -z "$port" ]; then
        echo "metals-repair: $d has no http port in log (isHttpEnabled off?) — cannot build-connect"
        return 1
      fi
      local out
      out=$(${pkgs.curl}/bin/curl -s -m 20 -X POST "http://127.0.0.1:$port/execute-command?command=build-connect" 2>&1 || true)
      # Accept empty (200 with no body) or any non-error body; reject on
      # unknown-command to avoid silently spamming a server that can't run it.
      if echo "$out" | grep -q 'Unknown command'; then
        echo "metals-repair: $d server rejected build-connect (unknown command)"
        return 1
      fi
      echo "metals-repair: $d sent build-connect via http port $port"
      return 0
    }
    check_reconnect_cooldown() { # <project-dir> -> 0 okay to reconnect
      local d=$1 marker
      marker="$COOLDOWN_DIR/.reconnect-$(echo "$d" | md5sum | cut -c1-12)"
      [ ! -f "$marker" ] && return 0
      find "$marker" -mmin +"$AUTO_REPAIR_COOLDOWN" -print -quit 2>/dev/null | grep -q . && return 0
      return 1
    }
    touch_reconnect_cooldown() { touch "$COOLDOWN_DIR/.reconnect-$(echo "$1" | md5sum | cut -c1-12)"; }
    check_compile_fix_cooldown() { # <project-dir> -> 0 okay to refresh
      local d=$1 marker
      marker="$COOLDOWN_DIR/.compile-fix-$(echo "$d" | md5sum | cut -c1-12)"
      [ ! -f "$marker" ] && return 0
      find "$marker" -mmin +30 -print -quit 2>/dev/null | grep -q . && return 0
      return 1
    }
    touch_compile_fix_cooldown() { touch "$COOLDOWN_DIR/.compile-fix-$(echo "$1" | md5sum | cut -c1-12)"; }

    # Shared: the running server's http command port, from the log.
    metals_http_port() { # <project-dir> -> port or empty
      grep 'Started Metals http server' "$1/.metals/metals.log" 2>/dev/null | tail -1 \
        | grep -oP '127\.0\.0\.1:\K[0-9]+' || true
    }

    # Failure mode 7: stale diagnostics. An "ERROR -- [E040]"-style compiler
    # diagnostic was published, the user fixed the source, but no compile
    # re-ran afterwards (the 60s editor-driven polling can stop with focus
    # loss, or the save landed while BSP was mid-reconnect). The editor
    # keeps showing the OLD squiggle forever. Refresh: ask the running
    # server for a cascade compile over http — fresh diagnostics re-publish.
    # Zero kills, cheap (incremental second-scale compile), 30-min cooldown.
    maybe_refresh_diagnostics() { # <project-dir> -> 0 if refresh triggered
      local d=$1 log last_e_ts last_e_epoch last_comp_ts port stale_src
      log="$d/.metals/metals.log"
      [ -f "$log" ] || return 1
      last_e_ts=$(grep -E 'ERROR -- \[E[0-9]+' "$log" 2>/dev/null | tail -1 | cut -c1-19 || true)
      [ -n "$last_e_ts" ] || return 1
      # Fresh compile AFTER the error → diagnostics already republished.
      last_comp_ts=$(grep 'time: compiled' "$log" 2>/dev/null | tail -1 | cut -c1-19 || true)
      if [ -n "$last_comp_ts" ] && [[ "$last_comp_ts" > "$last_e_ts" ]]; then return 1; fi
      # User touched sources after the error? That's what makes it stale.
      last_e_epoch=$(date -d "$(echo "$last_e_ts" | sed 's/\./-/g')" +%s 2>/dev/null || echo 0)
      [ "$last_e_epoch" -gt 0 ] || return 1
      stale_src=$(find "$d/src" -name '*.scala' -newermt "@$last_e_epoch" -print -quit 2>/dev/null || true)
      [ -n "$stale_src" ] || return 1
      check_compile_fix_cooldown "$d" || return 1
      port=$(metals_http_port "$d")
      if [ -z "$port" ]; then
        echo "metals-repair: $d has stale diagnostics but no http port — skipping refresh"
        return 1
      fi
      echo "metals-repair: $d stale diagnostics (last error $last_e_ts, source touched: $stale_src) — forcing compile-cascade"
      ${pkgs.curl}/bin/curl -s -m 30 -X POST \
        "http://127.0.0.1:$port/execute-command?command=compile-cascade" >/dev/null 2>&1 \
        && touch_compile_fix_cooldown "$d" || true
      return 0
    }
    check_compile_fix_cooldown() { # <project-dir> -> 0 okay
      local d=$1 marker
      marker="$COOLDOWN_DIR/.compile-fix-$(echo "$d" | md5sum | cut -c1-12)"
      [ ! -f "$marker" ] && return 0
      find "$marker" -mmin +30 -print -quit 2>/dev/null | grep -q . && return 0
      return 1
    }
    touch_compile_fix_cooldown() { touch "$COOLDOWN_DIR/.compile-fix-$(echo "$1" | md5sum | cut -c1-12)"; }

    # Main auto-repair loop: check status, conditionally repair.
    check_and_repair() {
      local d status_line severity
      mkdir -p "$COOLDOWN_DIR"
      # Global, once per cycle: reap scope-less orphans regardless of which
      # project (if any) they belonged to. Five-condition gate inside.
      reap_orphans
      while IFS= read -r d; do
        if repair_frozen "$d"; then
          echo "metals-repair: $d — AUTO-REPAIR FROZEN (crash-loop guard, 2h). Manual: systemctl --user start metals-repair-$(basename "$d" | tr -c 'a-zA-Z0-9_.' '-')"
          continue
        fi
        status_line=$(status_one "$d" 2>&1) || true
        case "$status_line" in
          RED\ *)
            echo "metals-repair: $status_line"
            # Failure mode 3: the 0% spin mints a fresh ERROR every few
            # seconds, so last-ERROR-age guard can never pass. Key only
            # on cooldown — status already proved ≥10 zero-progress lines.
            if echo "$status_line" | grep -q 'download_stall='; then
              if ! check_cooldown "$d"; then
                echo "metals-repair: auto-repair skipped for $d (cooldown active, $AUTO_REPAIR_COOLDOWN min)"
                continue
              fi
              echo "metals-repair: auto-repairing $d (download stall: JVM wedged at 0 bytes — hard restart)"
              repair_one "$d" || true
              touch_cooldown "$d"
              record_repair "$d"
              nudge_lsp_reattach "$d"; touch_nudge_cooldown "$d"
              continue
            fi
            # DNS/proxy failures are NOT repairable by restarting JVMs —
            # needs VPN/corp DNS. Hard repair here only burns the service
            # timeout on sbt probes that cannot succeed. Report and wait.
            if echo "$status_line" | grep -q 'DNS/proxy:'; then
              echo "metals-repair: $status_line (not auto-repairable — waiting for VPN/DNS; will re-check next tick)"
              continue
            fi
            # Guard 1: check stuck duration (must be RED for >N minutes)
            if ! check_stuck_duration "$d"; then
              echo "metals-repair: auto-repair skipped for $d (RED but <$AUTO_REPAIR_AFTER min, may be transient)"
              continue
            fi
            # Guard 2: check cooldown
            if ! check_cooldown "$d"; then
              echo "metals-repair: auto-repair skipped for $d (cooldown active, $AUTO_REPAIR_COOLDOWN min)"
              continue
            fi
            # All guards passed — auto-repair
            echo "metals-repair: auto-repairing $d (RED for >$AUTO_REPAIR_AFTER min, cooldown clear)"
            repair_one "$d" || true
            touch_cooldown "$d"
            record_repair "$d"
            nudge_lsp_reattach "$d"; touch_nudge_cooldown "$d"
            ;;
          YELLOW\ *)
            # Failure mode 7 pre-check: stale squiggle (error old, source
            # newer, no recompile since) → zero-kill cascade refresh first;
            # cheap enough to run even before the louder YELLOW paths below.
            maybe_refresh_diagnostics "$d" || true
            # Parse YELLOW fields: "YELLOW: no_target=X interrupts=Y last_compile=Z ..."
            local yt_no_target=0 yt_last_compile=""
            yt_no_target=$(echo "$status_line" | grep -oP 'no_target=\K[0-9]+' || echo 0)
            yt_last_compile=$(echo "$status_line" | grep -oP 'last_compile=\K[a-zA-Z0-9]+' || echo unknown)
            # YELLOW-no-target has two distinct sub-causes:
            #  (a) stale sbt daemon (age-gated) blocks a new connect
            #      → --soft repair kills it, metals reconnects on its own
            #  (b) NO sbt process at all: BSP initialize failed (typically
            #      during a DNS flap at JVM start) and metals never retries
            #      on its own — send build-connect via the http command
            #      port. Cheapest possible fix: zero kills.
            if [ "$yt_no_target" -gt 50 ] && [ "$yt_last_compile" = "never" ]; then
              local has_stale=0 have_sbt=0 pid
              for pid in $(pids_with_cwd 'sbt-launch\.jar' "$d" 2>/dev/null || true); do have_sbt=1; break; done
              for pid in $(pids_with_cwd_aged 'sbt-launch\.jar' "$d" 10 2>/dev/null || true); do
                has_stale=1; break
              done
              if [ "$has_stale" = 1 ]; then
                if check_cooldown "$d"; then
                  echo "metals-repair: auto-repairing $d (YELLOW: no_target=$yt_no_target, last_compile=$yt_last_compile, stale sbt detected)"
                  repair_one --soft "$d" || true
                  touch_cooldown "$d"
                  record_repair "$d"
                else
                  echo "metals-repair: $status_line (stale sbt detected, but cooldown active)"
                fi
              elif [ "$have_sbt" = 0 ]; then
                if check_reconnect_cooldown "$d"; then
                  echo "metals-repair: $status_line (BSP gave up connecting and no sbt is running — send build-connect, no kill)"
                  bsp_reconnect "$d" && touch_reconnect_cooldown "$d" || true
                else
                  echo "metals-repair: $status_line (BSP reconnect already attempted, cooldown active)"
                fi
              else
                echo "metals-repair: $status_line (no build targets, but sbt is fresh — waiting)"
              fi
            else
              echo "metals-repair: $status_line (reseed only)"
            fi
            reseed_cache
            ;;
          GREEN\ *)
            # Silently healthy — but an old compiler error line with newer
            # sources and no recompile = stale UI diagnostics (mode 7).
            maybe_refresh_diagnostics "$d" || true
            ;;
          GRAY\ *)
            # Metals not running (or no log yet). Reap orphaned background
            # sbt daemons (--detach-stdio, >10 min) that a previous repair
            # or crashed session left behind — they block the next BSP
            # connect when the client reopens. Interactive `sbt` in a
            # terminal is NOT --detach-stdio, so it is left alone.
            for pid in $(pids_with_cwd_aged 'sbt-launch\.jar.*--detach-stdio' "$d" 10 2>/dev/null || true); do
              echo "metals-repair: reaping orphaned sbt daemon pid $pid ($d, metals not running)"
              kill "$pid" 2>/dev/null || true
            done
            # Auto-reattach: a log (or its post-repair archive) was touched
            # recently but metals is dead — the client's LSP handle is
            # stale (Zed never restarts dead servers). If the project is
            # likely OPEN in an editor right now, bump _healTick in
            # .zed/settings.json; changing initialization_options forces
            # Zed to restart metals. Rate-limited by nudge cooldown.
            local nudgerecent=""
            for nlog in "$d/.metals/metals.log" "$d/.metals/metals.log.repaired"; do
              [ -f "$nlog" ] || continue
              [ -z "$(find "$nlog" -mmin +2880 -print -quit 2>/dev/null)" ] && nudgerecent=1
            done
            if [ -n "$nudgerecent" ] && check_nudge_cooldown "$d"; then
              nudge_lsp_reattach "$d"
              touch_nudge_cooldown "$d"
            fi
            ;;
          *)
            echo "metals-repair: $status_line"
            ;;
        esac
      done < <(discover_projects)
      echo "metals-repair: check-and-repair complete"
    }

    # Detect Scala version mismatch between sbt and the Metals log.
    # When sbt reports version X but Metals' log says Y, the H2 database
    # (.metals/metals.mv.db) has cached stale build targets for Y — the
    # client keeps falling back to the wrong PC, no build targets attach,
    # and the project stays stuck regardless of repair.
    # Outputs the log version if mismatched, empty if ok or check failed.
    detect_stale_version() { # <project-dir>
      local d=$1 log sbt_v log_v
      log="$d/.metals/metals.log"
      [ -f "$log" ] || return 0
      log_v=$(grep 'scala-library version' "$log" 2>/dev/null | tail -1 | grep -oP 'version: \K[0-9]+\.[0-9]+\.[0-9]+' || true)
      [ -n "$log_v" ] || return 0
      sbt_v=$(cd "$d" && timeout 60 sbt --no-colors --no-server -batch -Dsbt.log.noformat=true 'show scalaVersion' 2>&1 \
        | grep -oP '^\[info\] \K[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
      [ -n "$sbt_v" ] || return 0
      if [ "$log_v" != "$sbt_v" ]; then
        echo "$log_v"
        return 0
      fi
      return 1
    }

    repair_one() { # [--dry-run] [--soft] <dir>
      local dry=0 soft=0 d
      while true; do
        case "''${1:-}" in
          --dry-run) dry=1; shift ;;
          --soft) soft=1; shift ;;
          *) break ;;
        esac
      done
      d=$(expand_dir "''${1:?usage: repair [--dry-run] [--soft] <project-dir>}")
      guard_dir "$d"
      local pid owner
      # Kill BSP sbt processes (any age — these should not outlive repair).
      for pid in $(pids_with_cwd 'sbt-launch\.jar.*-bsp' "$d"); do
        if [ "$dry" = 1 ]; then echo "would kill sbt-bsp pid $pid"; else
          echo "metals-repair: stopping sbt-bsp pid $pid ($d)"
          kill "$pid" 2>/dev/null || true
        fi
      done
      # Kill stale sbt background daemons (--detach-stdio, older than 10 min).
      # These block Metals from starting a fresh BSP connection.
      for pid in $(pids_with_cwd_aged 'sbt-launch\.jar' "$d" 10); do
        if [ "$dry" = 1 ]; then echo "would kill stale sbt daemon pid $pid"; else
          echo "metals-repair: stopping stale sbt daemon pid $pid ($d)"
          kill "$pid" 2>/dev/null || true
        fi
      done
      # --soft mode: do NOT kill Metals. Zed does not auto-restart LSP
      # servers, so killing Metals leaves the editor permanently stuck.
      # Instead, kill only the sbt daemon and touch .bsp to signal reimport.
      if [ "$soft" = 0 ]; then
        for pid in $(pids_with_cwd 'scala.meta.metals.Main' "$d"); do
          owner=$(cat "/proc/$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null || echo 1)/comm" 2>/dev/null || echo unknown)
          if [ "$dry" = 1 ]; then echo "would kill metals pid $pid (ppid-owner: $owner)"; else
            echo "metals-repair: stopping metals pid $pid (owner: $owner, $d)"
            kill "$pid" 2>/dev/null || true
          fi
        done
        # Scope teardown (wrapper-scoped metals): one atomic kill of the
        # whole cgroup — JVM + every descendant (sbt BSP children, and
        # coursier fallback children that reparented and escaped pid
        # matching). Complements the pid kills above, which still catch
        # anything launched outside the wrapper.
        local scope_base scope
        scope_base=$(basename "$d" | tr -c 'a-zA-Z0-9_.' '-')
        if command -v systemctl >/dev/null 2>&1; then
          for scope in $(systemctl --user list-units --all --no-legend "metals-$scope_base-*.scope" 2>/dev/null | awk '{print $1}' | grep -E '^metals-' || true); do
            if [ "$dry" = 1 ]; then echo "would kill scope $scope (--kill-whom=all)"; else
              echo "metals-repair: killing scope $scope (wholesale: JVM + all descendants)"
              systemctl --user kill --kill-whom=all "$scope" 2>/dev/null || true
            fi
          done
        fi
      else
        echo "metals-repair: --soft mode, preserving Metals process(es) for $d"
      fi
      [ "$dry" = 0 ] && sleep 2 || true
      # Failure mode 3: with this project's JVMs dead their cache locks
      # are kernel-released; sweep unlocked leftovers so the reimport
      # cannot re-enter the 0% download spin. Also sweeps the default
      # cache (sbt resolves through it via the BSP shims).
      sweep_coursier_cache "$METALS_CACHE" "$dry"
      sweep_coursier_cache "$HOME/.cache/coursier/v1" "$dry"
      local rel
      for rel in .bloop .metals/metals.lock.db; do
        if [ -e "$d/$rel" ]; then
          if [ "$dry" = 1 ]; then echo "would rm -rf $d/$rel"; else rm -rf "$d/$rel"; echo "metals-repair: removed $d/$rel"; fi
        fi
      done
      # Auto-detect stale version: sbt reports X, metals log says Y.
      # The H2 database has cached build targets for Y — clean it so the
      # client re-imports with the correct version.
      local stale_v
      stale_v=$(detect_stale_version "$d" || true)
      if [ -n "$stale_v" ]; then
        if [ "$dry" = 1 ]; then
          echo "would rm -rf $d/.metals/metals.mv.db (stale version $stale_v)"
        else
          rm -rf "$d/.metals/metals.mv.db"
          echo "metals-repair: removed .metals/metals.mv.db (stale version $stale_v — sbt reports different scalaVersion)"
        fi
      fi
      if [ -d "$d/.bsp" ]; then
        find "$d/.bsp" -maxdepth 1 -name '*.lock' -o -maxdepth 1 -name 'metals.sbt.lock' | while read -r f; do
          if [ "$dry" = 1 ]; then echo "would rm $f"; else rm -f "$f"; echo "metals-repair: removed $f"; fi
        done
        echo "metals-repair: preserved $d/.bsp/sbt.json"
      fi
      # Hard repair only: archive metals.log so status_one cannot keep
      # matching historical download_stall/DNS lines after the JVM is
      # gone (append-mode log would otherwise poison the next tick).
      # Soft repair preserves Metals — leave its log alone.
      if [ "$soft" = 0 ] && [ "$dry" = 0 ] && [ -f "$d/.metals/metals.log" ]; then
        mv -f "$d/.metals/metals.log" "$d/.metals/metals.log.repaired" 2>/dev/null || true
        echo "metals-repair: archived $d/.metals/metals.log -> metals.log.repaired"
      fi
      if [ "$dry" = 1 ]; then echo "would reseed cache + touch $d/.bsp"; return 0; fi
      reseed_cache
      touch "$d/.bsp"
      echo "metals-repair: done for $d — refocus the client to trigger reimport, then run: metals-repair status --project $d"
    }

    cmd="''${1:-status}"; shift || true
    case "$cmd" in
      status)
        if [ "''${1:-}" = "--project" ]; then status_one "$(expand_dir "''${2:?}")"; exit $?
        elif [ "''${1:-}" = "--all" ] || [ $# -eq 0 ]; then
          worst=0; d=
          while IFS= read -r d; do status_one "$d" || { rc=$?; [ "$rc" -gt "$worst" ] && worst=$rc; }; done < <(discover_projects)
          exit "$worst"
        else status_one "$(expand_dir "$1")"; exit $?; fi;;
      repair) repair_one "$@";;
      reseed-cache|reseed) reseed_cache;;
      check-and-repair) check_and_repair;;
      discover) discover_projects;;
      *) echo "usage: metals-repair {status [--all|--project DIR]|repair [--dry-run] DIR|reseed-cache|check-and-repair|discover}" >&2; exit 2;;
    esac
  '';

  projectUnits = lib.listToAttrs (map
    (dir: {
      name = svcOf dir;
      value = {
        Unit.Description = "Metals repair for ${baseOf dir} (manual, scoped)";
        Service = {
          Type = "oneshot";
          ExecStart = "${repairBin}/bin/metals-repair repair --project '${dir}'";
        };
      };
    })
    rcfg.projects);
in
{
  options.devtools.scala.repair = {
    enable = lib.mkEnableOption "declarative Metals auto-repair (client-agnostic)";

    projects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "~/IdeaProjects/doc-manager" ];
      description = "Explicit allowlisted sbt project dirs (may use ~). Repair refuses anything else.";
    };

    autoDiscover = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Also discover ~/IdeaProjects/*/build.sbt plus live metals/sbt cwd at runtime (eval never touches $HOME).";
    };

    cacheGcTtl = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = "TTL for coursier gc, kept in sync with metals-wrapper COURSIER_TTL.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "OnCalendar for the reseed-only timer. Repair itself is never on a timer.";
    };

    enableTimer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the weekly reseed-only timer.";
    };

    autoRepair = lib.mkEnableOption "auto-repair stuck projects when RED for longer than autoRepairAfter minutes";

    autoRepairAfter = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Minutes of continuous RED before auto-repair triggers (avoids false positives during VPN transitions).";
    };

    autoRepairCooldown = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Minimum minutes between auto-repairs for the same project (prevents repair loops).";
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "OnUnitActiveSec for the check-and-repair timer when autoRepair is on. Frequent enough to catch 0% download spins before they idle for hours.";
    };
  };

  config = lib.mkIf (cfg.enable && rcfg.enable) {
    assertions = [
      {
        assertion = rcfg.projects != [ ];
        message = "devtools.scala.repair.projects must not be empty when repair is enabled.";
      }
      {
        assertion = lib.all (d: d != "/" && d != "~" && d != "$HOME") rcfg.projects;
        message = "devtools.scala.repair.projects must not contain / or bare home.";
      }
      {
        assertion =
          let bases = map baseOf rcfg.projects;
          in lib.length bases == lib.length (lib.unique bases);
        message = "devtools.scala.repair.projects must have unique basenames (service units are per-basename).";
      }
    ];

    home.packages = [ repairBin ];

    systemd.user.services = projectUnits // {
      metals-reseed = {
        Unit.Description = "Metals cache reseed (safe, no deletes outside caches)";
        Service = {
          Type = "oneshot";
          ExecStart = "${repairBin}/bin/metals-repair reseed-cache";
        };
      };
    } // lib.optionalAttrs rcfg.autoRepair {
      metals-check = {
        Unit.Description = "Metals health check + conditional auto-repair";
        Service = {
          Type = "oneshot";
          ExecStart = "${repairBin}/bin/metals-repair check-and-repair";
          # Hard repair can include an sbt version probe (up to 60s) and
          # a cache reseed per project; 300s died mid-loop on the second
          # project. 900s covers 7 projects with margin.
          TimeoutStartSec = 900;
        };
      };
    };

    systemd.user.timers = lib.optionalAttrs rcfg.enableTimer {
      metals-reseed = {
        Unit.Description = "Weekly Metals cache reseed";
        Timer = {
          OnCalendar = rcfg.schedule;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    } // lib.optionalAttrs rcfg.autoRepair {
      # Frequent reactive check: catches 0% download spins (and RED/YELLOW
      # regressions) within checkInterval instead of waiting for the weekly
      # reseed. OnUnitActiveSec chains from the last run; OnBootSec seeds
      # the first tick after login.
      metals-check = {
        Unit.Description = "Periodic Metals health check + conditional auto-repair";
        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = rcfg.checkInterval;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
