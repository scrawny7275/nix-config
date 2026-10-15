# NixOS Garbage Collection Roots Solution

## Problem Statement

After running `nix-collect-garbage -d` (user), the home-manager profile and its **transitive flake input sources** were being garbage collected, causing `home-manager switch --flake ~/nix-config#user` to re-download dependencies from cache.nixos.org on every run.

The system rebuild (`sudo nixos-rebuild switch`) was unaffected because its GC roots live in `/nix/var/nix/gcroots/` (root-owned), which user-level GC cannot touch.

## Root Cause

Two distinct problems:

1. **Home-manager closure not pinned** — the home-manager generation and its `.drv` had no GC root outside `~/.local/state/nix/profiles/`, so user GC deleted them.

2. **Transitive flake input sources not pinned** — only 21 top-level flake inputs were pinned, but the 76 transitive inputs (sub-flakes' nixpkgs, flake-compat, systems, rust-overlay, hypr* deps, etc.) were not. These source paths are **evaluation-time dependencies**: they exist in the Nix store after `nix flake` evaluation but are **not referenced by any `.drv` file's closure**. They're raw fetched trees that only the Nix evaluator uses.

## Solution Architecture

The entire solution lives in **`modules/user/nix/gc-roots.nix`** (user module only). The system module is untouched.

### Hook 1: `pin-flake-inputs` (runs after `writeBoundary`)

Recursively traverses the entire flake input tree at **Nix evaluation time** and generates `nix-store --add-root --indirect -r` calls for every source path.

```nix
collectInputPaths = prefix: inputSet:
  lib.concatMapAttrs (name: input:
    let
      path = input.outPath or null;
      subInputs = input.inputs or {};
      subPaths = collectInputPaths "${prefix}/${name}" subInputs;
    in
    if path != null then
      { "${prefix}/${name}" = path; } // subPaths
    else
      subPaths
  ) inputSet;
```

This walks `inputs.ags.inputs.nixpkgs`, `inputs.hyprland.inputs.aquamarine`, etc. — all 76+ transitive inputs. Each gets a GC root symlink in `~/.local/state/nix/gcroots/flake-inputs/`.

### Hook 2: `pin-home-closure` (runs after `installPackages`)

Pins the home-manager generation and its `.drv` via `nix-store --add-root --indirect -r`:

```bash
nix-store --add-root .../home-closure/home-manager --indirect -r $HM_PATH
nix-store --add-root .../home-closure/home-manager-drv --indirect -r $DRV_PATH
```

The `-r` flag registers the **entire closure**, protecting all build-time dependencies.

### Option: `modules.user.nix.gc-roots.verbose`

| Type | Default | Effect |
|------|---------|--------|
| `bool` | `false` | When `true`, prints summary after each hook. When `false`, all `nix-store` output is silenced (`>/dev/null 2>&1`). |

## Why User-Only (No System Module Changes)

The user explicitly declined modifying the system module (`modules/system/nix/gc-roots.nix`) because previous attempts broke `sudo nixos-rebuild switch --flake ~/nix-config#laptop --impure`.

The user module approach works because:
- `nix-store --add-root --indirect` creates roots in `/nix/var/nix/gcroots/auto/` which are respected by GC regardless of who creates them
- The `inputs` module argument is already resolved at eval time — no network calls needed
- Recursive traversal catches all transitive inputs automatically

## Verification

```bash
# 1. Apply the fix
home-manager switch --flake ~/nix-config#user

# 2. Run garbage collection
nix-collect-garbage -d

# 3. Verify no re-download
home-manager switch --flake ~/nix-config#user
# Should complete without "copying path from cache.nixos.org" lines
```

### Debugging

```bash
# Check GC roots exist
ls ~/.local/state/nix/gcroots/flake-inputs/ | wc -l
# Should show 76+ entries

ls ~/.local/state/nix/gcroots/home-closure/
# Should show home-manager and home-manager-drv

# Check indirect roots are registered
ls /nix/var/nix/gcroots/auto/ | grep -c "$(id -un).*gcroots"
```

## Files

| File | Purpose |
|------|---------|
| `modules/user/nix/gc-roots.nix` | User-level GC root pinning (recursive flake inputs + home closure) |
| `modules/system/nix/gc-roots.nix` | System-level pinning (4 top-level inputs only, unchanged) |

## Option Usage

```nix
# In hosts/laptop/home.nix or any imported module:
modules.user.nix.gc-roots.verbose = true;  # enable logging
```
