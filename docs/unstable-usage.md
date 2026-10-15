# Unstable packages usage

## Why per-module, not global

    If globally in the standalone Home Manager declaration has this:

        ```nix
          specialArgs = { unstable = ...; };
        ```

    This is a global escape hatch. Every module could silently import unstable without the host explicitly saying so. Problems: - Hidden lifecycle dependencies. A stable host could accidentally pull in unstable packages without anyone noticing. - Hard to reason about: reading flake.nix gives no clue which host actually uses which unstable package. - Makes evaluation non-local: unstable is injected globally, so you can’t predict exactly what a module sees just by reading that module.

    The selected approch is to do local imports where needed:

    ```nix
      # modules/user/hyprland/packages.nix
    { inputs, pkgs, ... }:

    let
      unstable = import inputs.unstable { inherit (pkgs.stdenv.hostPlatform) system; };
    in
    {
    home.packages = [ unstable.someNewThing ];
    }

    ```

    Here:

    - Lifecycle is explicit per module.
    - Only modules that need unstable packages import nixpkgs-unstable.
    - No hidden side-effects; the flake itself remains boring, declarative, and readable.

    Think of it as scoping unstable to where it’s used, instead of letting it leak everywhere.
