# AI tools manual setup

Covers every `modules/user/ai/*` component that is not fully declarative:
what must be done by hand, in which order, and how to verify it.
Fully declarative parts (packages, units, plugin wiring) are owned by the
Nix modules and are not repeated here.

Related docs:

- `docs/sops-secrets-encryption.md` — editing `secrets/laptop.yaml`
- `docs/independent-sops-secrets.md` — age keys, encrypting new files

## Principles

1. Secrets live only in `secrets/laptop.yaml` (sops) and are referenced via
    `sops.secrets."api_keys/..."` with `mode = "0600"` (repo convention,
    see `opencode.md`).
2. Never paste a key into a `.nix` file, shell history on shared machines,
    or chat logs. Keys must never land in the Nix store: OpenCode provider
    keys use the `{file:...}` secret-file indirection (`providers.nix`);
    non-OpenCode consumers (the supermemory plugin config) use
    `sops.templates`, rendered at activation with `0600`.
3. Bootstrap order is always: add placeholder secret -> switch ->
    capture generated credential -> update sops -> switch again -> verify.
4. After every switch, verify the service and the consumer (commands below).

## Universal sops workflow

```bash
sops secrets/laptop.yaml   # add/update keys under api_keys:, save to re-encrypt
home-manager switch --flake .#user
```

A secret declared in a module but missing from the yaml fails activation,
so add the key (even a placeholder) before switching.

## 1. Supermemory, local mode (default)

The server mints its own API key on first boot; there is nothing to obtain
upfront.

1. Ensure `supermemory_local` exists in `secrets/laptop.yaml`
    (temporary value is fine).
2. Switch. The `supermemory` user unit starts and first boot creates
    `~/.local/share/supermemory/` (module default `dataDir`).
3. Read the generated key (do not paste it anywhere except sops):
    `cat ~/.local/share/supermemory/api-key`
    (fallback: `journalctl --user -u supermemory`, it is in the boot banner).
4. Replace the temporary value in sops with the real key, switch again.
    The `opencode/supermemory.jsonc` template picks it up.
5. Verify: `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:6767/`
    (expect `200`), then restart OpenCode and run
    `bunx opencode-supermemory status`.

Notes: first boot downloads the embedding model, so it takes a while.
The module points extraction at the local OmniRoute gateway
(`http://127.0.0.1:20128/v1`, model `auto`). Upstream binds `0.0.0.0`
with no bind-address knob in v0.0.8 — treat port 6767 as LAN-reachable.

## 2. Supermemory, cloud mode

1. Mint a key at `https://console.supermemory.ai`, store it as
    `api_keys/supermemory_cloud` in sops.
2. Set `modules.user.ai.supermemory.mode = "cloud"`, switch.
3. The local unit file stays behind but is no longer managed; stop it once:
    `systemctl --user stop supermemory`.
4. Restart OpenCode, run `bunx opencode-supermemory status`.

## 3. FreeLLMAPI

Two manual credentials:

- `api_keys/freellmapi_encryption`: self-generated. This encrypts upstream
  provider keys at rest in its SQLite DB. Generate once, never rotate
  without wiping its data dir:
  `openssl rand -hex 32`
- `api_keys/freellmapi_unified`: minted by the service itself. Switch,
  open the dashboard at `http://127.0.0.1:3001`, copy the unified key
  into sops, switch again. The `freellmapi` OpenCode provider
  (`http://127.0.0.1:3001/v1`, model `auto`) uses it.

Optional: add upstream provider keys in the same dashboard for non-free
models. Upstream docs: `https://github.com/tashfeenahmed/freellmapi`.

## 4. OmniRoute

No manual step for the free pool: the module runs with
`REQUIRE_API_KEY=false` and OpenCode sends the dummy key `free`
(`modules.user.ai.omniroute.apiKey`). Dashboard at
`http://127.0.0.1:20128` (port option `modules.user.ai.omniroute.port`).

Optional, via dashboard: add subscription/API keys to unlock Tier 1-3
routing. Upstream docs: `https://github.com/diegosouzapw/omniroute`.

Recommendation (upstream Docker guide): coding-agent workloads want
`-e OMNIROUTE_MEMORY_MB=8192 --memory=10g`; the image default (1024)
can `FATAL ERROR` under overlapping long `/v1/responses` calls.
The module currently sets neither — consider adding options if the
gateway OOMs under load.

## 5. Provider API keys (OpenCode `providers.nix`)

Each row: sops name -> where to mint -> consumer.

| sops key | Mint at | Consumed by |
| --- | --- | --- |
| `api_keys/opencode_zen` | opencode.ai dashboard (Zen API key) | `provider.opencode` |
| `api_keys/gemini` | Google AI Studio (`aistudio.google.com`) | `provider.google` |
| `api_keys/openrouter` | `openrouter.ai/keys` | `provider.openrouter` |
| `api_keys/unorouter` | unorouter dashboard (`api.unorouter.com`) | `provider.unorouter` |
| `api_keys/aihubmix` | aihubmix dashboard (`aihubmix.com`) | `provider.aihubmix` |
| `api_keys/freellmapi_unified` | FreeLLMAPI dashboard (section 3) | `provider.freellmapi` |

Verify a provider after adding its key: switch, then in OpenCode
`/models` (or start a session with that provider) and confirm no auth error.

## 6. Plugins

- `context-mode`: no manual step (npm plugin, configured by settings).
- `opencode-supermemory`: config file is rendered by `sops.templates`
  (local baseUrl `http://localhost:6767`, cloud
  `https://api.supermemory.ai`). Only manual part is the API key
  (sections 1-2). Verify with `bunx opencode-supermemory status`.

## 7. Mode switching (supermemory)

`modules.user.ai.supermemory.mode`:
- `local` (default): needs `supermemory_local` (section 1).
- `cloud`: needs `supermemory_cloud` (section 2) + manual
  `systemctl --user stop supermemory` once.
- `off`: plugin removed from OpenCode settings (context-mode only),
  no secret required.

## 8. Audit findings (declared secrets with no consumer)

Checked against `modules/` on 2026-09-18. No action required, listed so
nobody mistakes them for wired credentials:

- `api_keys/kimi`, `api_keys/token_router`, `api_keys/pollinations`:
  declared in `opencode/secrets.nix` and present in yaml, but no provider
  references them (providers were removed/renamed). Dormant until a
  provider is re-added.
- `api_keys/omnirouter`: declared in `omniroute.nix` and present in yaml,
  but the unit never consumes it (dummy `free` key is used). Dormant.
- `api_keys/claude_platform`, `api_keys/openai_platform`: declared and
  present, no consumer yet. Pending future providers.
- `api_keys/supermemory_cloud`: declared only in cloud mode; add to yaml
  when (not before) switching to cloud mode.

## 9. Resource limits & ONNX native fix (2026-09-21)

### Problem

With multiple OpenCode sessions running, the system experienced freezes
and occasional OOM kills. Investigation revealed:

1. **supermemory-server memory exhaustion:** The server peaked at
   **27.6 GB** (cgroup peak: 20.2 GB) on a 30 GB system. The kernel
   OOM killer intervened. The previous instance also hit 18.4 GB before
   being stopped.

2. **WASM embedding fallback:** The native onnxruntime binding
   (`onnxruntime_node`) requires `libstdc++.so.6`, which was not
   available at runtime on NixOS. This forced a fallback to WASM
   embeddings, which are significantly slower and consume more memory.

3. **No resource limits:** None of the three AI services (supermemory,
   omniroute, freellmapi) had any cgroup or container memory/CPU limits.

4. **Orphaned test processes:** Two test copies of supermemory had been
   running from `/tmp` since Sep 18, wasting ~500 MB combined.

### Decisions

**Resource limits applied:**

| Service | Directive | Value | Rationale |
|---------|-----------|-------|-----------|
| supermemory | `MemoryMax` | `3G` (configurable via `maxMemory` option) | Hard cap prevents runaway growth. Previous peak was 27.6 GB. |
| supermemory | `MemoryHigh` | `2G` | Soft cap triggers kernel memory reclaim pressure before hard limit. |
| supermemory | `CPUQuota` | `200%` | Caps to 2 cores. Embedding extraction is CPU-bound. |
| supermemory | `IOWeight` | `50` | Lower IO priority (default 100) reduces disk contention when contended. |
| omniroute | `--memory` | `1g` | Lightweight API gateway, no local inference. RSS ~230 MB. |
| omniroute | `--cpus` | `2` | Consistent with supermemory CPU cap. |
| freellmapi | `--memory` | `1g` | Lightweight aggregator, no local inference. RSS ~245 MB. |
| freellmapi | `--cpus` | `2` | Consistent with supermemory CPU cap. |

**Why these values:** On a 30 GB system with desktop (~2 GB), browser
(~2 GB), and 6 OpenCode sessions (~4.5 GB), the AI services collectively
use at most ~5 GB (supermemory 3G + omniroute 1G + freellmapi 1G),
leaving ~20.5 GB for the rest of the system. The `maxMemory` option
allows tuning without code changes.

**ONNX native fix approach:**

- `pkgs/supermemory/default.nix` declares `stdenv.cc.cc.lib` in
  `buildInputs`. The `autoPatchelfHook` adds the gcc-lib store path
  to the binary's RPATH at build time.
- The service environment sets
  `LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib` as a fallback for
  dynamically loaded `.node` addons (onnxruntime loads at runtime, not
  at link time).
- `modules/system/nix/nix-ld.nix` adds `stdenv.cc.cc.lib` to the
  system-wide nix-ld library list, covering any future unpatched
  binaries that need `libstdc++.so.6`.

**Why not just nix-ld:** The nix-ld approach is system-wide and
invasive. The package-level `buildInputs` fix is scoped to supermemory
only. The `LD_LIBRARY_PATH` fallback handles the case where onnxruntime
loads `.node` files dynamically (outside autoPatchelfHook's scope).
Using both approaches provides defense in depth.

### Restart loop protection

systemd services with `Restart = on-failure` can enter a restart loop
if the root cause is persistent (e.g. memory leak, consistently
exceeding `MemoryMax`). The sequence:

1. Server starts, memory grows past `MemoryMax` (3G)
2. Kernel OOM killer fires `SIGKILL`
3. systemd sees failure, restarts after `RestartSec` (5s)
4. Server starts, memory grows past 3G again
5. Repeat forever — each cycle wastes resources and causes IO churn

To prevent this, the supermemory unit declares:

```nix
StartLimitBurst = 3;       # max 3 start attempts
StartLimitIntervalSec = 300; # within a 5-minute window
```

If the service fails 3 times within 5 minutes, systemd **stops
restarting it**. The service status will show `Result: start-limit-hit`
and remain in a failed state until you intervene:

```bash
# Check why it's failing
systemctl --user status supermemory
journalctl --user -u supermemory -n 50

# After fixing the root cause, reset the failure counter and restart
systemctl --user reset-failed supermemory
systemctl --user start supermemory
```

**How each resource limit behaves:**

| Directive | On hit | Process killed? | Behavior |
|-----------|--------|-----------------|----------|
| `MemoryHigh` (2G) | Kernel reclaim pressure | No | Process slows down as kernel forces memory reclaim. Performance degrades, process continues. |
| `MemoryMax` (3G) | OOM killer | Yes (`SIGKILL`) | Kernel kills the process immediately. No graceful shutdown. systemd restarts per `Restart=` policy. |
| `CPUQuota` (200%) | CPU throttle | No | Process gets less CPU time when contended. No kill, just slower. |
| `IOWeight` (50) | IO deprioritization | No | Process gets less disk bandwidth relative to other processes. No kill, just slower IO. |

**Monitoring memory at runtime:**

```bash
# Current cgroup memory stats
cat /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/supermemory.service/memory.current

# OOM event counters (increment when limits are hit)
cat /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/supermemory.service/memory.events
# Output: low N high N max N oom N oom_kill N oom_group_kill N
# Non-zero "max" or "oom_kill" means the hard cap was hit.
```

### Secret-in-argv exposure fix (freellmapi)

**Problem (2026-09-25):** The freellmapi unit interpolated the sops secret
directly into the podman command line:

```nix
-e ENCRYPTION_KEY="$(cat ${config.sops.secrets."api_keys/freellmapi_encryption".path})"
```

This embedded the decrypted key in the podman process **argv**, readable by
any same-uid process via `ps`, `/proc/<pid>/cmdline`, and
`systemctl --user status` (the cgroup process listing prints full command
lines). The key was observed verbatim in a `systemctl status` transcript.

**Fix:** render the env file declaratively via `sops.templates` (the same
mechanism already used for the supermemory plugin config), and pass it to
podman with `--env-file` instead of an inline `-e`:

```nix
sops.templates."freellmapi/env" = {
  path = "/run/user/1000/freellmapi-env";
  mode = "0600";
  content = ''
    ENCRYPTION_KEY=${config.sops.placeholder."api_keys/freellmapi_encryption"}
  '';
};
# podman run ... --env-file "$env_file" ...
```

The start script also got `set -euo pipefail` plus a non-empty guard so a
missing template fails loudly instead of booting the container with an empty
key.

**Why `sops.templates` over alternatives:**

- *systemd `LoadCredential`:* rejected — it can't feed podman directly; an
  ExecStart(Pre) script would still be needed to turn the credential file
  into an env file. Two mechanisms (LoadCredential + shell) to do what one
  (sops template) already does.
- *podman native secrets:* rejected for rootless — the rootless secrets
  backend stores values **unencrypted** on disk, which downgrades the
  protection sops provides.
- *RuntimeDirectory + ExecStartPre script:* workable, but reinvents-file-based
  secret delivery when sops.templates already has the exact semantics needed
  (atomic render, 0600, tmpfs, deleted on reboot).

**Residual exposure (accepted):** `podman inspect freellmapi` still shows the
env value under `Config.Env` to anyone who can talk to the user's podman
socket — same-uid only, which matches the existing sops threat model (all
same-uid processes can already read `/run/user/1000/secrets*` if they race
before a `-c 600`, and podman socket access implies full user privilege
anyway).

### Files changed

| File | Change |
|------|--------|
| `pkgs/supermemory/default.nix` | Added `buildInputs = [ stdenv.cc.cc.lib ]` |
| `modules/user/ai/supermemory.nix` | Added `maxMemory` option, resource limits (`MemoryHigh`, `MemoryMax`, `CPUQuota`, `IOWeight`), `LD_LIBRARY_PATH` env, restart loop protection (`StartLimitBurst`, `StartLimitIntervalSec`) |
| `modules/user/ai/omniroute.nix` | Added `--memory 1g` and `--cpus 2` to podman run |
| `modules/user/ai/freellmapi.nix` | Added `--memory 1g` and `--cpus 2` to podman run; secret moved from argv to `--env-file` via `sops.templates."freellmapi/env"` (2026-09-25) |
| `modules/system/nix/nix-ld.nix` | Added `stdenv.cc.cc.lib` to nix-ld libraries |

### Verification

```bash
# After home-manager switch:
systemctl --user status supermemory
# Expected: Memory: 1.XG (high: 2G, max: 3G)

journalctl --user -u supermemory -n 20 --no-pager
# Expected: No "falling back to WASM" error; embeddings loaded locally

podman inspect omniroute --format '{{.HostConfig.Memory}}'
# Expected: 1073741824 (1 GB)

podman inspect freellmapi --format '{{.HostConfig.Memory}}'
# Expected: 1073741824 (1 GB)

# Secret hygiene — must return 0 (no key in any process argv):
ps -eo args | grep 'ENCRYPTION_KEY=' | grep -vc grep
```