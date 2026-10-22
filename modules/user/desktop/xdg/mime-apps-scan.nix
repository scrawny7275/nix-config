# modules/user/desktop/xdg/mime-apps-scan.nix
# Existence gate for xdg MIME defaults — the activation-time half of the
# candidate registry (see default.nix). The eval-time registry is a
# FITNESS gate (is this ID allowed for the role); this scan is an
# EXISTENCE gate (does the desktop file actually exist in the
# post-switch environment). It catches what the registry cannot: a typo
# pasted identically into both a role's value and its candidate
# registration, or an app dropped from the profile while its candidate
# lives on. Complements modules/user/app/desktop-entry-guard.nix — the
# guard PRUNES dangling handwritten entries; this module never deletes,
# it only vetoes. Caveat: mimeapps.list is already linked when this
# fires (entryAfter linkGeneration) — a failure is loud but the previous
# links stay applied; fix forward and re-switch.
{ config, lib, ... }:

let
  cfg = config.modules.user.desktop.xdg.mimeAppsScan;

  mimeMap = config.xdg.mimeApps.defaultApplications;

  ids = lib.unique (lib.concatLists (lib.mapAttrsToList (_: v: lib.toList v) mimeMap));

  mimesFor =
    id:
    lib.concatStringsSep ", "
      (builtins.attrNames (lib.filterAttrs (_: v: builtins.elem id (lib.toList v)) mimeMap));
in
{
  options.modules.user.desktop.xdg.mimeAppsScan = {
    enable = lib.mkEnableOption "activation-time existence scan for xdg MIME defaultApplications";
  };

  config = lib.mkIf cfg.enable {
    home.activation.mimeAppsScan = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      bad=0
      check() {
        id="$1"; mimes="$2"; found=""
        for d in \
          "''${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
          "${config.home.profileDirectory}/share/applications" \
          "/run/current-system/sw/share/applications" \
          ''${XDG_DATA_DIRS:+$(IFS=:; for x in $XDG_DATA_DIRS; do echo "$x/applications"; done)}
        do
          [ -e "$d/$id" ] && {
            found=1
            break
          }
        done
        if [ -z "$found" ]; then
          echo "[xdg-scan] MISSING desktop entry: $id (used by MIME types: $mimes)"
          bad=1
        fi
      }
      ${lib.concatStringsSep "\n" (map (id: "      check '${id}' '${mimesFor id}'") ids)}
      if [ "$bad" -ne 0 ]; then
        echo "[xdg-scan] xdg.mimeApps.defaultApplications reference desktop files that do not exist — aborting switch." >&2
        exit 1
      fi
    '';
  };
}
