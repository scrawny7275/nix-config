# flake.nix
{
  description = "NixOS + Flakes + Standalone Home Manager";

  inputs = {
    stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    # unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    unstable.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "stable";

    sops-nix.url = "github:Mic92/sops-nix";

    hyprland.url = "github:hyprwm/Hyprland";
    niri.url = "github:sodiboo/niri-flake";
    ironbar.url = "github:JakeStanger/ironbar";
    ironbar.inputs.nixpkgs.follows = "stable";
    helium.url = "github:AlvaroParker/helium-nix";
    helium-flake.url = "github:oxcl/nix-flake-helium-browser";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    awww.url = "git+https://codeberg.org/LGFae/awww";
    shell.url = "github:andre-brandao/gpui-shell";
    shell.inputs.nixpkgs.follows = "stable";
    astal.url = "github:aylur/astal";
    ags.url = "github:aylur/ags";
    nix-jetbrains-plugins.url = "github:nix-community/nix-jetbrains-plugins";
    nix-jetbrains-plugins.inputs.nixpkgs.follows = "stable";

    # stable.follows = "nixos-cosmic/nixpkgs";
    nixos-cosmic.url = "github:PhoenixPhantom/nixos-cosmic";
    cosmic-manager.url = "github:HeitorAugustoLN/cosmic-manager";
    crane.url = "github:ipetkov/crane";

    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "stable";

    sonora.url = "github:sonorahq/sonora";
    opencode.url = "github:anomalyco/opencode/v1";

    # Data-only private input. Public tree carries the stub; the real working
    # environment lives in ~/nix-config-private (never published) and is swapped
    # in per-invocation with:
    #   --override-input private path:$HOME/nix-config-private
    private = {
      url = "path:./share/private-stub";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      # Values from the private input (public stub by default, private override
      # when supplied). Drives the home-manager configuration attribute name.
      privateValues = import (inputs.private + "/values.nix");

      # All inputs needed by both system and home-manager (for GC root pinning)
      allInputs = {
        inherit (inputs)
          stable
          unstable
          home-manager
          sops-nix
          hyprland
          niri
          ironbar
          helium
          helium-flake
          zen-browser
          awww
          shell
          astal
          ags
          nix-jetbrains-plugins
          cosmic-manager
          plasma-manager
          nixos-cosmic
          crane
          sonora
          opencode
          private
          ;
      };

      # Inputs passed to NixOS system modules
      systemInputs = {
        inherit (inputs)
          stable
          unstable
          sops-nix
          nixos-cosmic
          private
          ;
      };

      # Inputs passed to Home Manager modules
      homeInputs = {
        inherit (inputs)
          stable
          unstable
          home-manager
          sops-nix
          hyprland
          niri
          ironbar
          helium
          helium-flake
          zen-browser
          awww
          shell
          astal
          ags
          nix-jetbrains-plugins
          cosmic-manager
          plasma-manager
          nixos-cosmic
          crane
          sonora
          opencode
          private
          ;
      };

      forAllSystems = inputs.stable.lib.genAttrs [ "x86_64-linux" ];

      legacyPackages = forAllSystems (
        system:
        let
          pkgs = inputs.stable.legacyPackages.${system};
        in
        {
          scala-2_13_5 = pkgs.callPackage ./modules/shared/pkgs/scala-2_13_5.nix { };
          sbt-1_4_7 = pkgs.callPackage ./modules/shared/pkgs/sbt-1_4_7.nix {
            jdk = pkgs.temurin-bin-11;
          };
          wordcraft = pkgs.callPackage ./pkgs/wordcraft { };
          pdfcraft = pkgs.callPackage ./pkgs/pdfcraft { };
          deckcraft = pkgs.callPackage ./pkgs/deckcraft { };
          blanc = pkgs.callPackage ./pkgs/blanc { };
          opencode = pkgs.callPackage ./pkgs/opencode {
            upstreamCliVersion = inputs.opencode.packages.${system}.opencode.version;
          };
        }
      );

    in
    {
      nixosConfigurations.laptop = inputs.stable.lib.nixosSystem {
        specialArgs.inputs = allInputs;
        modules = [ ./hosts/laptop/system.nix ];
      };

      homeConfigurations.${privateValues.userName} = inputs.home-manager.lib.homeManagerConfiguration {
        # Standalone home-manager does not see the NixOS-level unfree
        # predicate, so import nixpkgs with the same allow-list here
        # (hosts/laptop/packages/unfree-list.nix is the single source).
        pkgs = import inputs.stable {
          system = "x86_64-linux";
          config.allowUnfreePredicate =
            pkg: builtins.elem (inputs.stable.lib.getName pkg) (import ./hosts/laptop/packages/unfree-list.nix);
        };
        extraSpecialArgs.inputs = homeInputs;
        modules = [ ./hosts/laptop/home.nix ];
      };

      packages = legacyPackages;

      apps = forAllSystems (
        system:
        let
          pkgs = inputs.stable.legacyPackages.${system};
        in
        {
          # Detect imperative leftovers in user-bin (~/.local/bin must be fully
          # declarative: everything resolves into the nix store).
          # Usage: nix run .#audit-strays
          audit-strays = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "audit-strays" ''
                bad=0
                for f in "$HOME"/.local/bin/*; do
                  [ -e "$f" ] || continue
                  target=$(readlink -f "$f")
                  case "$target" in
                    # declarative = resolves anywhere into the store (home-manager
                    # links end up as either *-home-manager-files/* bundles or
                    # direct writeShellScriptBin derivations)
                    /nix/store/*) : ;;
                    *) echo "STRAY: $f -> $target"; bad=1 ;;
                  esac
                done
                [ "$bad" -eq 0 ] && echo "OK: ~/.local/bin fully declarative" || exit 1
              ''
            );
          };
        }
      );

      # Unit tests for this repo's own module logic (see tests/default.nix).
      # `nix flake check` runs these; failures abort evaluation by name.
      checks.x86_64-linux.unit =
        let
          pkgs = inputs.stable.legacyPackages.x86_64-linux;
          failures = inputs.stable.lib.debug.runTests (import ./tests { lib = inputs.stable.lib; });
        in
        if failures == [ ] then
          pkgs.runCommand "unit-tests-pass" { } "touch $out"
        else
          throw "unit tests failed: ${toString (map (f: f.name) failures)}";

      # The closed xdg candidate registry (docs/xdg-mime-defaults.md) is a
      # config-forcing gate: it fires on any eval of the home configuration
      # and on the activationPackage build (the switch), but plain
      # `nix flake check` does not force that depth — force it here so CI
      # enforces the registry too. Empirically verified: without this check,
      # flake check passes while an unregistered roleApps selection would
      # abort the switch.
      checks.x86_64-linux.xdg-registry =
        let
          lib = inputs.stable.lib;
          home = inputs.self.homeConfigurations.${privateValues.userName};
          failed = lib.filter (a: !a.assertion) home.config.assertions;
        in
        if failed == [ ] then
          inputs.stable.legacyPackages.x86_64-linux.runCommand "xdg-registry-pass" { } "touch $out"
        else
          throw "xdg registry assertions failed: ${toString (map (a: a.message) failed)}";
    };
}
