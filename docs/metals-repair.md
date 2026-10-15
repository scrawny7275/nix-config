# Metals LSP: auto-repair architecture

**Scope.** Declarative, client-agnostic recovery for Metals language-server
degradation across all sbt projects under `~/IdeaProjects`. Detection keys on
project directories (`/proc/<pid>/cwd` + log path), never on the editor.

## Failure modes (history)

1. Stale sbt `--detach-stdio` background daemon blocks a fresh BSP connect.
2. `bloopVersion` (even one stale key in a merged settings.json) sends Metals
   into the Bloop trap (ClassNotFoundException, no fallback to sbt BSP).
3. Coursier 0% download spin on a black-holed socket or stale lock
   (`0.00 %, 0 / N` flooded as fresh ERRORs, so ERROR-age guards never fire).
4. Orphaned coursier children (`cs fetch`, cwd=$HOME) survive a dead server
   and hold `*.jar.lock` flocks that poison the next start.
5. Zed never restarts dead LSP servers (editor limitation).
6. **BSP connect gives up silently**: `build/initialize` TimeoutException
   during a DNS flap at JVM start → "Failed to connect with build server" →
   metals never retries on its own → YELLOW no_target storm forever even
   after DNS recovers. No sbt process to blame (it exited), so the stale-sbt
   repair gate never fires. Fix: `build-connect` via the running server's
   HTTP command port (`isHttpEnabled=true` in initialization_options);
   zero kills. Verified live 2026-09-26: `curl -X POST
   http://127.0.0.1:<port>/execute-command?command=build-connect` recovered
   doc-manager ("Connected to build server in 25s; Imported build").
7. **Stale diagnostics (squiggle on already-fixed code)**: a compiler
   `ERROR -- [E0xx]` is published; the user fixes and saves the file, but
   no compile re-runs afterwards (the editor's save→compile chain depends
   on focus/client behavior — observed 2026-09-26: fix saved at 11:41,
   log frozen since 11:36, error stayed visible). Detection: newest
   `.scala` mtime under `src/` is later than the last compiler ERROR, and
   no `time: compiled` line follows that error. Fix: `compile-cascade`
   via the http command port → fresh diagnostics republish; the false
   squiggle clears. Zero kills, 30-min `.compile-fix-<md5>` cooldown,
   incremental compile (seconds). Verified live: cascade cleared E040 and
   compiled all targets.
8. **TTL-triggered revalidation storms during a network flap (resolved)**:
   coursier measures TTL from each cached artifact's file mtime, and
   downloaded artifacts carry the upstream `Last-Modified` — seed jars
   stamped mid-2025 were long past the 720h window, so every fresh JVM
   start revalidated online; on 2026-10-05 during a network flap this
   produced ~850 `pc_fail` errors in ~20 min (self-resolved when the
   network settled). Fix: `reseed_cache` now `touch`es all seeded files,
   restarting the TTL window on every activation and timer-driven reseed.

**Modules.**
- `modules/user/devtools/scala-toolchain/metals-wrapper.nix` — launcher +
  cache seeding + BSP shims.
- `modules/user/devtools/scala-toolchain/metals-repair.nix` — status,
  repair, systemd units/timers.
- `modules/user/devtools/zed-editor/default.nix` — client wiring (Zed).
- Enabled per host in `hosts/laptop/home.nix` (`devtools.scala.repair.*`).

## Components

| Component | Mechanism | Key facts |
|---|---|---|
| `~/.local/bin/metals-wrapper` | shell wrapper, `systemd-run --user --scope` when D-Bus present, else plain `exec` | `JAVA_TOOL_OPTIONS`: corp truststore, `defaultConnectTimeout=5000`, `defaultReadTimeout=30000` (failure mode 3 self-limiter), DNS TTL 30s/10s (VPN transitions). `COURSIER_CACHE` → private seeded cache; `COURSIER_REPOSITORIES` central-first (off-VPN works); `COURSIER_TTL=720h` (no online revalidation of seeded set). Scope name `metals-<projname>-<pid>.scope`: cgroup membership survives orphaning, so one scope kill reaps the whole subtree including reparented coursier fallback children. Verified on systemd 260: stub TERM forwards to child, stub death collects the scope. |
| PC cache seed | FOD `metals-pc-deps` + activation script | Byte-identical hash-locked Scala-3 PC set copied under **every** repo key (repo1, nexus, nexus-3, sonatype snapshots) — coursier keys its v1 cache per repo URL. Re-seeded (overwrite) on every HM switch = corruption self-heal. Also seed-merges the **default** coursier cache (sbt's) under the repo1 key, and sweeps corrupt `org/scala-lang`,`org/scalameta` jars (`jar tf` gate). |
| `~/.local/bin/sbt-bsp` | shim, kills stale sbt daemons then `exec sbt` | Keeps sbt/scala-cli children on the default coursier cache (unsets `COURSIER_CACHE`). |
| `metals-repair` binary | status / repair / reseed-cache / check-and-repair | See tables below. Deletes are allowlisted to derived dirs under a guarded project dir (refuses `/`, `$HOME`, outside `$HOME`, no `build.sbt`). `.bsp/sbt.json` preserved. |
| `metals-check.timer` | every 10 min (`OnBootSec=2min`, `OnUnitActiveSec=10min`) | Runs `check-and-repair`. `TimeoutStartSec=900` (7 projects × sbt probe × reseed margin). |
| `metals-reseed.timer` | weekly | Reseed-only cadence. |
| `metals-repair-<proj>` units | oneshot, manual | `systemctl --user start metals-repair-<proj>` = scoped hard repair. |
| Cooldown markers | `~/.cache/metals-repair/.auto-repair-<md5(dir)[0:12]>` | mtime; per-project; blocks re-repair for `autoRepairCooldown` (60 min). |
| Nudge markers | `~/.cache/metals-repair/.nudge-<md5>` | Rate-limits forced LSP restarts to one per cooldown window. |
| Crash-loop guard | `~/.cache/metals-repair/.repair-log-<md5>` + `.repair-frozen-<md5>` | >2 auto-repairs in 60 min → project frozen for 2h (loud journal line + manual escape hatch). Guards against repair → reopen → re-fail cascades. |

## Detection (`status_one`, per project)

Signals from `tail -300 .metals/metals.log` plus full-log greps, plus a
live-process gate (`pgrep scala.meta.metals.Main` whose `/proc/<pid>/cwd`
is the project).

| Signal | Filter | Threshold |
|---|---|---|
| `dl0` — `(0.00 %, 0 / N)` download lines | last 15 min, anchored to leading timestamp lines | ≥10 → RED `download_stall` |
| `dns` / `pc_fail` — UnknownHost/Connect/SocketTimeout / PC-resolve failures | last 15 min | >0 → RED `DNS/proxy` |
| compile loop: `Processing buildTarget` ≥3, `time: compiled`=0, `Unmatched cancel` ≥3 | tail-300, **no** recency filter | → RED |
| cancels/interrupts >0 or `no build target` >5 | tail-300, no recency filter | → YELLOW |
| no live metals JVM | `/proc` fd/cwd gate | → GRAY (patterns reported as "historical") |

## Reactions (`check_and_repair` per tick)

| State | Action |
|---|---|
| GREEN | No log anomalies — but still runs mode-7: stale squiggle pre-check (error old, sources newer, no compile since) → force compile-cascade. |
| GRAY | + Reap orphaned `--detach-stdio` sbt daemons (cwd-gated, >10 min). + Reap *scope-less* orphans once per cycle via `reap_orphans` — five-condition gate: same uid, parent dead (PPID 1 or the user's systemd), no TTY, age ≥ `autoRepairAfter`, holds an fd inside a coursier cache. This catches Metals' coursier CLI fallback children (`cs fetch`, cwd=$HOME) that survive a dead server and hold `*.jar.lock` flocks poisoning the next start. + Reap *orphaned scopes*: any `metals-*.scope` with no `scala.meta.metals.Main` inside is definitionally orphaned — `systemctl --user kill --kill-whom=all` tears down the whole cgroup. + Auto-reattach: if a log (or post-repair archive) was touched in the last 2 days, the project is likely open in an editor → `nudge_lsp_reattach` bumps `_healTick` in `.zed/settings.json` (created if absent; never clobbers hand-written settings). Changing `initialization_options` forces Zed to restart metals — this is the automatic reattach. Rate-limited by nudge cooldown. |
| YELLOW | Reseed caches. Then, if `no_target>50` AND `last_compile=never`: split by sub-cause. (a) Stale sbt daemon exists (>10 min, age-gated via `etimes`) → `--soft` repair (kills sbt, preserves metals). (b) **No sbt at all** (BSP gave up during a DNS flap) → `bsp_reconnect` sends `build-connect` over the running server's http port; zero kills; `.reconnect-<md5>` cooldown. |
| RED `download_stall` | Hard repair (below) if cooldown clear. The >autoRepairAfter ERROR-age guard is skipped — the spin mints fresh ERRORs continuously. Then crash-loop record + auto-reattach nudge. |
| RED `DNS/proxy` | **Report only.** Needs VPN/DNS; hard repair would burn the timeout on doomed sbt probes. |
| RED compile loop | Hard repair if last ERROR > `autoRepairAfter` (20 min) AND cooldown clear, then record + nudge. |

**Hard repair (`repair_one`)**: kill project-scoped sbt BSP → stale sbt
daemons → metals JVMs (skipped in `--soft`) → `systemctl --user kill
--kill-whom=all` on every `metals-<proj>-*.scope` for the project (cgroup
wholesale teardown: catches coursier children that reparented out of pid
matchers) → sweep coursier locks/partials (only files no JVM holds open:
`readlink` of every java pid's fds; `.part` age-gated 15 min) + orphan
`.checked` markers, both caches → remove `.bloop`, `.metals/metals.lock.db`
→ if sbt's `scalaVersion` (probed, `timeout 60`, `--no-server` so no daemon
spawn) differs from the log's, remove `.metals/metals.mv.db` → archive
`metals.log → metals.log.repaired` (hard mode only) → reseed caches →
touch `.bsp` (client reimport trigger, `autoImportBuilds=all`) →
auto-reattach nudge.

## Invariants

1. Repair never deletes anything outside a guarded project's derived dirs
   and the two coursier caches.
2. Sweep never deletes a file a JVM holds open.
3. `--soft` never kills metals (client-restart blindness compatibility).
4. PCB caches are merge-only from a hash-locked FOD; runtime downloads are
   overwritten back to the pinned set on every switch.
5. Auto-repair is rate-limited: ≥1 exceptional condition + cooldown marker.
6. Seeds are offline: no repair path requires working DNS.

## Known limits (read before trusting GREEN/exit-0)

1. **GRAY ≠ healthy for the user.** It means "no wedged JVM, nothing to
   detox." Since the auto-reattach nudge (2026-09-24) a GRAY tick also
   *reattaches* the client when the log is < 2 days old — so the editor
   recovers on its own now. The residual gap is only for projects whose
   log/archive is older than 2 days (safe no-op: they're likely not open
   anyway) or whose `.zed/settings.json` is hand-written (we refuse to
   touch it; add an `_healTick` key yourself to opt in).
2. **Zombie/stale client status**: after a repair kills a client-spawned
   metals, the client may hold an unreaped zombie and a stale label until
   the nudge forces a restart. The nudge closes this — observed live:
   tick bump → `metals-doc-manager--<pid>.scope` spawns fresh, log shows
   `Connected to Build server: sbt` → `Imported build`.
3. **Orphan blindness is closed for scope-launched JVMs** (every new
   metals launch goes through the wrapper → `systemd-run --user --scope`,
   descendants enumerable + killable wholesale) and best-effort for
   pre-scope relicts (the five-condition `reap_orphans` gate). A
   hand-launched `nohup cs fetch` whose terminal closed matches the gate
   (known, accepted false-positive surface).
4. **etime mis-parse — FIXED.** Age gates now read `etimes` (elapsed
   seconds integer) instead of parsing the ambiguous `MM:SS`/`HH:MM:SS`
   format that made every ">10 min" gate fire at ~1 min. Applies to
   metals-repair and `sbt-bsp` alike.
5. **No recency filter on compile-loop signals**: after a kill, the frozen
   log's tail (cancels/interrupts/processing) feeds the next tick's
   tail-300 counts. Hard repair archives the log to neutralize this;
   `--soft` deliberately does not. A reopened healthy JVM can inherit
   stale YELLOW/RED until new lines push the old storm out of the tail.
6. **DNS/proxy RED is terminal by design**: no repairs; the system waits
   for the network. `networkaddress.cache.negative.ttl=10` in the wrapper
   makes recovery propagate within seconds once VPN is up.
7. **bloopVersion trap — twice burned, now double-guarded.** Its mere
   presence in `lsp.metals.settings` makes Metals attempt Bloop startup
   ("No running Bloop server found, starting one" → ClassNotFoundException)
   and a failed attempt does NOT fall back to sbt BSP despite
   `defaultBspToBuildTool=true`. First fix removed it from the Nix source;
   the home-manager activation merges (`dynamic * static`), so the stale
   key persisted in `~/.config/zed/settings.json` — second fix deleted it
   from the file directly. If Bloop ever reappears in the log, check for a
   stale `bloopVersion` key first.
8. **Multi-client**: several metals JVMs per project (Zed + opencode) is
   normal; each gets its own scope, one repair kills them all.
9. **Crash-loop guard**: >2 auto-repairs in 60 min freezes the project for
   2 h with a loud journal line. Manual escape:
   `systemctl --user start metals-repair-<proj>` (also safe: it's the same
   guarded repair path, just cooldown-free).
10. **COURSIER_REPOSITORIES ordering matters**: `central` must come FIRST
    (publicly reachable, fast-fail), nexus after. nexus-first off-VPN means
    NXDOMAIN timeouts slow every resolution. Set in
    `hosts/laptop/home.nix` `systemd.user.sessionVariables`.
11. **`cs gc` does nothing in this coursier version** (2.1.24): prints the
    generic usage block. The repair sweep is the real cache hygiene; the
    gc call is kept quiet as forward-compat only.

## Operator runbook

```shell-script
metals-repair status --all                    # health view
metals-repair repair --dry-run <dir>          # preview
systemctl --user start metals-repair-<proj>   # manual scoped repair
journalctl --user -u metals-check.service     # what the timer decided
ls -la ~/.cache/metals-repair/                # cooldown state
```

After any hard repair: reopen the project in the client (this restarts the
LSP — nothing else can).
