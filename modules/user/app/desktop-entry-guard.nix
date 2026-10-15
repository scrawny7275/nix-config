# modules/user/app/desktop-entry-guard.nix
{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.user.app.desktopEntryGuard;
in
{
  options.modules.user.app.desktopEntryGuard = {
    enable = lib.mkEnableOption ''
      pruning of dangling desktop entries in ~/.local/share/applications.

      Handwritten (non-symlink) .desktop files there embed absolute
      /nix/store paths; after nix-collect-garbage they become unloadable but
      still shadow nix-profile entries of the same ID (XDG_DATA_HOME
      outranks XDG_DATA_DIRS), silently breaking desktop-entry launchers
      such as tide-island. Entries whose Exec/TryExec store paths no longer
      exist are removed on activation; symlinked (HM-managed) entries are
      never touched.
    '';
  };

  config = lib.mkIf cfg.enable {
    home.activation.desktopEntryGuard = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      appsDir="${config.xdg.dataHome}/applications"
      if [ -d "$appsDir" ]; then
        for f in "$appsDir"/*.desktop; do
          [ -e "$f" ] || continue
          [ -L "$f" ] && continue
          [ -f "$f" ] || continue
          dangling=""
          for sp in $(grep -E '^(Exec|TryExec)=' "$f" | grep -oE '/nix/store/[a-z0-9]{32}[^"[:space:]]*' | sort -u || true); do
            if [ ! -e "$sp" ]; then
              dangling="$sp"
              break
            fi
          done
          if [ -n "$dangling" ]; then
            echo "desktop-entry-guard: removing dangling entry $f (missing $dangling)"
            rm -f "$f"
          fi
        done
      fi
    '';
  };
}
