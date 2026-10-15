# modules/user/nix/gc-roots.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.user.nix.gc-roots;

  collectInputPaths = prefix: inputSet:
    lib.concatMapAttrs (name: input:
      let
        path = input.outPath or null;
        subInputs = input.inputs or {};
        subPaths = collectInputPaths "${prefix}/${name}" subInputs;
      in
      if path != null then
        (if lib.isAttrs subPaths then { "${prefix}/${name}" = path; } // subPaths else { "${prefix}/${name}" = path; })
      else
        subPaths
    ) inputSet;

  allInputPaths = collectInputPaths "flake-inputs" inputs;

  pinLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path:
    ''pin "${name}" "${path}"''
  ) allInputPaths);

  inputCount = builtins.length (builtins.attrNames allInputPaths);

  verbose = cfg.verbose;
in
{
  options.modules.user.nix.gc-roots = {
    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable verbose logging during GC root pinning";
    };
  };

  config = {
    home.activation.pin-flake-inputs = lib.hm.dag.entryAfter [ "writeBoundary" ] (''
      mkdir -p "${config.xdg.stateHome}/nix/gcroots/flake-inputs"

      pin() {
        local name="$1" path="$2"
        if [ -e "$path" ]; then
          local safe_name="$(${pkgs.coreutils}/bin/echo "$name" | ${pkgs.coreutils}/bin/tr '/' '_')"
          ${pkgs.nix}/bin/nix-store --add-root "${config.xdg.stateHome}/nix/gcroots/flake-inputs/$safe_name" --indirect -r "$path" ${if verbose then "" else ">/dev/null 2>&1"} || true
        fi
      }

      # Pin all ${toString inputCount} flake inputs (top-level + transitive)
      ${pinLines}
    '' + lib.optionalString verbose ''

      echo "Pinned ${toString inputCount} flake inputs to GC roots"
    '');

    home.activation.pin-home-closure = lib.hm.dag.entryAfter [ "installPackages" ] (''
      mkdir -p "${config.xdg.stateHome}/nix/gcroots/home-closure"
      HM_PATH="$(${pkgs.coreutils}/bin/readlink -f "${config.xdg.stateHome}/nix/profiles/home-manager")"
      if [ -n "$HM_PATH" ] && [ -e "$HM_PATH" ]; then
        ${pkgs.nix}/bin/nix-store --add-root "${config.xdg.stateHome}/nix/gcroots/home-closure/home-manager" --indirect -r "$HM_PATH" ${if verbose then "" else ">/dev/null 2>&1"} || true
        DRV_PATH="$(${pkgs.nix}/bin/nix-store -q --deriver "$HM_PATH" 2>/dev/null || true)"
        if [ -n "$DRV_PATH" ] && [ -e "$DRV_PATH" ]; then
          ${pkgs.nix}/bin/nix-store --add-root "${config.xdg.stateHome}/nix/gcroots/home-closure/home-manager-drv" --indirect -r "$DRV_PATH" ${if verbose then "" else ">/dev/null 2>&1"} || true
        fi
      fi
    '' + lib.optionalString verbose ''

      echo "Pinned home-manager closure to GC roots"
    '');
  };
}
