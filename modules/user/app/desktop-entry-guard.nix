# modules/user/app/desktop-entry-guard.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.app.desktopEntryGuard;
in
{
  options.modules.user.app.desktopEntryGuard = {
    enable = lib.mkEnableOption ''
      pruning of dangling desktop entries in ~/.local/share/applications.

      Handwritten or app-emitted (non-symlink) .desktop files there embed absolute
      /nix/store paths; after nix-collect-garbage they become unloadable but
      still shadow nix-profile entries of the same ID (XDG_DATA_HOME
      outranks XDG_DATA_DIRS), silently breaking desktop-entry launchers
      such as tide-island. Entries whose Exec/TryExec store paths no longer
      exist — or whose ELF target cannot resolve its dynamic libraries
      (raw extracted AppImage binaries are store-resident but unlaunchable
      outside an FHS wrap) — are removed on activation; symlinked
      (HM-managed) entries are never touched.
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
              dangling="$sp (missing)"
              break
            fi
            # Existence is not launchability: a raw extracted AppImage ELF
            # sits in the store but resolves none of its dynamic libs
            # outside an FHS wrap (2026-10-20 anytype shadow-entry
            # incident). The ELF-magic gate keeps scripts, data files and
            # static binaries out of scope.
            if "${pkgs.coreutils}/bin/head" -c4 "$sp" \
              | "${pkgs.coreutils}/bin/od" -An -tx1 \
              | "${pkgs.gnugrep}/bin/grep" -q '7f 45 4c 46' \
              && "${pkgs.glibc.bin}/bin/ldd" "$sp" 2>/dev/null \
              | "${pkgs.gnugrep}/bin/grep" -q '=> not found'; then
              dangling="$sp (unlaunchable ELF: unresolved dynamic libs)"
              break
            fi
          done
          if [ -n "$dangling" ]; then
            echo "desktop-entry-guard: removing dangling entry $f: $dangling"
            rm -f "$f"
          fi
        done
      fi
    '';
  };
}
