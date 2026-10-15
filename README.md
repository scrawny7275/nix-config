# NixOS Configuration (outdated)

Personal NixOS system and standalone Home Manager configuration.
Built as a Nix flake with impure evaluation due to a hardware-configuration.nix
symlink (see [Known Limitations](#known-limitations)).

> **Architecture principle:** System modules configure the machine.
> Home Manager modules configure the user. Shared policy lives in
> `modules/shared/`. Host-specific packages live in `hosts/<name>/packages/`.

---

## Roadmap
  Completetly declare all my used web browsers with shared host-based:
    - extensions
    - search egienes

## Daily Workflow

```bash
# Full update and apply
nix flake update
sudo nixos-rebuild switch --flake .#laptop
home-manager switch --flake .#<user>  # attribute name comes from the private private input
```

> **Warning:** `nixos-rebuild` and `home-manager switch` evaluate the flake
> independently. Updating the lock file and running only one command leaves
> the other on the old revision. Always run both.

---

## Current Desktop Stack

**Primary compositor:** [Niri](https://github.com/YaLTeR/niri) (KDL-based config)

**Shell components:**

- **tide-island** — Quickshell-based dynamic island (launcher, notifications, control center)
  (this is currently disabled)- **cosmic-ext-alternative-startup** — OSD, app launcher, lock screen (from Cosmic DE)
  (this is disable)- **niri-wallpaper** — Wallpaper with blurred desktop overview background
  (not working)- **eww-splash** — Cycling splash messages over wallpaper (pending AGS migration)
- **foot** — Terminal emulator

**Disabled fallbacks:** Plasma 6, Cosmic DE standalone, mako notifications

> The desktop is intentionally minimal: media consumption basics plus
> development tooling. Launched from TTY via `niri-cosmic`.

---

## Architecture

(outdated)

```text
modules/
├── system/              # NixOS-only (boot, services, networking, hardware)
│   ├── desktop/
│   │   ├── x11.nix          # X11 baseline (currently disabled)
│   │   ├── cosmic.nix       # Cosmic DE (stable pkgs only, no overlay)
│   │   └── plasma.nix       # Plasma 6 (disabled)
│   └── ...
├── user/                # Home Manager only
│   ├── desktop/
│   │   ├── niri/
│   │   │   ├── hm/          # HM JSON-generating configs
│   │   │   ├── kdl/         # KDL-generating configs (active)
│   │   │   └── cosmic-ext/  # Cosmic integration for Niri
│   │   ├── qt.nix           # Qt/Breeze theming
│   │   └── xdg/             # MIME associations
│   ├── devtools/            # Languages, editors, containers
│   ├── ai/                  # AI tooling (opencode)
│   ├── media/               # GStreamer, etc.
│   └── ...
├── shared/
│   ├── lib/                 # Pure functions (jdk-packages.nix, etc.)
│   ├── pkgs/                # Custom package definitions
│   └── themes/
└── hosts/
    └── laptop/
        ├── system.nix
        ├── home.nix
        ├── packages/
        │   ├── system.nix
        │   └── user.nix
        └── hardware.nix -> /etc/nixos/hardware-configuration.nix
```

**Scope rules:**

- `hosts/<name>/system.nix` → NixOS options only (`services.*`, `boot.*`, `hardware.*`)
- `hosts/<name>/home.nix` → HM options only (`programs.*`, `home.*`, `xdg.*`)
- Modules needing both are split into `modules/system/` and `modules/user/` counterparts
- Multi-file modules use directories with `default.nix` when exceeding ~150 lines

---

## AI Services & Resource Limits

Three local AI services run as systemd user services. All were originally
unconstrained, which caused system freezes when multiple OpenCode sessions
were active simultaneously.

**Root cause (2026-09-21):** `supermemory-server` peaked at **27.6 GB**
of memory on a 30 GB system due to WASM embedding fallback (native
`libstdc++.so.6` was missing on NixOS). The kernel OOM killer had to
intervene. See [docs/ai-manual-setup.md](docs/ai-manual-setup.md)
for the full investigation and fix.

| Service     | Type                | Memory           | CPU            | IO        | Module                            |
| ----------- | ------------------- | ---------------- | -------------- | --------- | --------------------------------- |
| supermemory | Native binary (Bun) | 3G max / 2G soft | 200% (2 cores) | Weight 50 | `modules/user/ai/supermemory.nix` |
| omniroute   | Podman container    | 1 GB             | 2 cores        | —         | `modules/user/ai/omniroute.nix`   |
| freellmapi  | Podman container    | 1 GB             | 2 cores        | —         | `modules/user/ai/freellmapi.nix`  |

**supermemory `maxMemory` option:** configurable via
`modules.user.ai.supermemory.maxMemory` (default `"3G"`). Tune upward if
the server OOMs under heavy embedding workloads; lower if memory is tight.

**ONNX native binding fix:** `pkgs/supermemory/default.nix` declares
`stdenv.cc.cc.lib` in `buildInputs` so `autoPatchelfHook` can resolve
`libstdc++.so.6` for the onnxruntime-node native addon. The service
environment also sets `LD_LIBRARY_PATH` pointing to the gcc-lib store
path as a belt-and-suspenders fallback. A system-wide `nix-ld` entry
(`modules/system/nix/nix-ld.nix`) covers any other unpatched binaries.

**Verification after rebuild:**

```bash
# Supermemory — check memory cap and ONNX status
systemctl --user status supermemory
journalctl --user -u supermemory -n 20 --no-pager

# Containers — verify Podman resource limits
podman inspect omniroute --format '{{.HostConfig.Memory}}'
podman inspect freellmapi --format '{{.HostConfig.Memory}}'
```

---

## Toolchain Highlights

| Domain  | Stack                                                                         |
| ------- | ----------------------------------------------------------------------------- |
| Java    | Multi-version (8, 11, 17, 21), default 17. Shared `jdk-packages.nix` library. |
| Scala   | Scala 3 + SBT via nixpkgs. Corporate Nexus repos via `COURSIER_REPOSITORIES`. |
| Go      | gopls, delve. Corporate proxy vars currently disabled.                        |
| Nix     | nil LSP, nixfmt, nix-idea plugin                                              |
| Editors | Zed (primary), IDEA Community (Scala/Java)                                    |

---

## Known Limitations

- **Impure evaluation:** `hardware-configuration.nix` is a symlink to
  `/etc/nixos/hardware-configuration.nix`. This avoids committing disk UUIDs
  but requires `--impure` for flake evaluation.
- **No `osConfig` passthrough:** Standalone HM cannot read system state.
  Duplication is required where HM needs to know system configuration.
- **Version skew risk:** See [Daily Workflow](#daily-workflow).

---

## Updating

See [docs/unstable-usage.md](docs/unstable-usage.md) for unstable package policy.

```bash
# Update all inputs
nix flake update

# Update single input
nix flake lock --update-input home-manager
```

Garbage collection: see [docs/clean-up-old-generations.md](docs/clean-up-old-generations.md)
