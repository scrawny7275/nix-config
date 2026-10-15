# NixOS Flakes + Home Manager — Dependency Troubleshooting Guide

Quick reference for determining which package is pulling in a problematic dependency (e.g., insecure/EOL Electron) and how to decide what to do about it.

## Prerequisites

```bash
nix-shell -p nix-tree
```

## Step-by-Step Workflow

  1.  Temporarily allow the insecure package to build
    Option A — Build the system closure without switching:

          ```bash
            cd ~/nix-config
             NIXPKGS_ALLOW_INSECURE=1 nix build --impure .#nixosConfigurations.laptop.config.system.build.toplevel
          ```

          This creates a ./result symlink.

    Option B — If you already switched successfully with the env var:

    ```bash
      sudo NIXPKGS_ALLOW_INSECURE=1 nixos-rebuild switch --flake ~/nix-config#laptop --impure
    ```

    Then use /run/current-system directly in step 2.
  2. Inspect with nix-tree
  
    ```bash
      # If you built locally:
      nix-tree ./result
    ```

# If you already switched:

nix-tree /run/current-system 3. Find the culprit inside nix-tree
Table
Key Action
/ Open search prompt
electron Type the package name
n Jump to next match
N Jump to previous match
r Toggle reverse tree — shows what depends on the selected item
↑ / ↓ Navigate up/down the tree
Enter Expand/collapse node
Recommended approach:
Press /, type electron, hit Enter
Press n until you land on electron-XX.X.X
Press r to switch to reverse tree view
Look directly above electron — that package is the immediate parent declaring the dependency
Navigate up with ↑ to see the full chain back to your system configuration 4. Identify the source in your config
Once you know the package name (e.g., discord, element-desktop, obsidian), search your configuration:
bash
cd ~/nix-config
grep -r "discord" --include="_.nix" .
grep -r "element-desktop" --include="_.nix" .
grep -r "obsidian" --include="\*.nix" .
Check both:
configuration.nix / hosts/ → environment.systemPackages
home.nix / home/ → home.packages
Decision Matrix
Once you know which package is the culprit, choose one of these actions:
Table
Situation Action Command / Config
Package updated in newer nixpkgs Update flake inputs nix flake update ~/nix-config
Package is non-essential Remove it Delete from home.packages or environment.systemPackages
Package is essential but EOL is acceptable risk Permit it explicitly Add to nixpkgs.config.permittedInsecurePackages (see below)
Package is essential and has a newer alternative Replace it Swap for an alternative (e.g., discord-canary, web version, etc.)
Permitting an insecure package (intentional)
In your NixOS configuration:
nix
{
nixpkgs.config.permittedInsecurePackages = [
"electron-39.8.10"
];
}
In Home Manager standalone (~/.config/nixpkgs/config.nix or via nixpkgs.config in home.nix):
nix
{
nixpkgs.config.permittedInsecurePackages = [
"electron-39.8.10"
];
}
⚠️ Only do this if you understand the risk (e.g., the application is sandboxed, network-isolated, or you accept running EOL Electron).
Common Culprits (Electron-based apps)
These packages frequently lag behind on Electron updates:
discord
element-desktop / riot-desktop
obsidian
logseq
joplin-desktop
ferdi / franz / rambox
etcher
drawio
standardnotes
Quick Reference Commands
bash

# Build system closure without switching (allow insecure)

NIXPKGS_ALLOW_INSECURE=1 nix build --impure .#nixosConfigurations.laptop.config.system.build.toplevel

# Inspect result

nix-tree ./result

# Inspect current system

nix-tree /run/current-system

# Find store path of electron

nix-store -q --references /run/current-system | grep electron

# See why current system depends on a specific path

nix why-depends /run/current-system /nix/store/...electron-XX.X.X

# Search your config for a package

grep -r "<package-name>" --include="\*.nix" ~/nix-config

# Update all flake inputs

nix flake update ~/nix-config

# Update a specific input only

nix flake lock --update-input nixpkgs ~/nix-config
Home Manager Standalone Note
If you use Home Manager standalone (not as a NixOS module), also check your user profile:
bash

# Build home generation

NIXPKGS_ALLOW_INSECURE=1 home-manager build --impure --flake ~/nix-config#user
nix-tree ./result

# Or inspect an existing generation

home-manager generations
nix-tree /nix/store/...home-manager-generation
Remember
Never blindly add packages to permittedInsecurePackages — always identify the culprit first.
Prefer updating (nix flake update) over permitting EOL software.
Prefer removing non-essential apps over carrying security debt.
Use nix-tree reverse view (r) — it is the fastest way to trace a dependency backwards.
