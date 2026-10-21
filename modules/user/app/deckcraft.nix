# modules/user/app/deckcraft.nix
# storytold/deckcraft — the ArtCraft presentation app (sibling of
# wordcraft/pdfcraft). deckcraft-cli ships inside the GUI release tarball.
# The GUI binary is wrapped with DECKCRAFT_WAYLAND=1 (see pkgs/deckcraft):
# like wordcraft, deckcraft prefers XWayland whenever X is reachable, and its
# X11 window opens full-monitor-size, which niri renders edge-to-edge
# ("fullscreen"). The wrapper forces native Wayland. Escape hatch: run
# .deckcraft-wrapped directly. pdfcraft needs no wrapper — its vendored winit
# defaults to Wayland even with X available.
#
# Appearance (user decision 2026-10-20): deckcraft has NO system-theme
# detection — verified against its binary (zero portal/dconf literals) and
# upstream source (no theme.rs; its siblings wordcraft/pdfcraft ship one).
# Its Dark Mode state persists as the misleadingly-named "brightness" field
# of ui.json ("light"|"dark"; applied from loaded state at startup). The
# activation below seeds that field from the declared appearance option —
# the same source that feeds the dconf color-scheme — so every home-manager
# switch re-syncs the app to the declared system theme. Real-time tracking
# would require the upstream portal fix; if deckcraft is running during a
# switch its own on-exit save wins and the next switch re-seeds.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  deckcraft = pkgs.callPackage ../../../pkgs/deckcraft { };

  # Default handler for the presentation family (user decision 2026-10-20).
  # mkDefault: the generic xdg module's plain entries and host overrides
  # (modules.user.desktop.xdg.extraDefaultApplications) win.
  dc = lib.mkDefault "ai.storyteller.deckcraft.desktop";

  # DeckCraft's UiState.brightness enum is exactly Light|Dark (no "system"
  # variant); every declared color scheme except prefer-dark maps to light.
  brightness =
    if config.appearance.colorScheme == "prefer-dark"
    then "dark"
    else "light";

  seedJson = pkgs.writeText "deckcraft-appearance.json" (
    builtins.toJSON { brightness = brightness; }
  );

  # Brave merge-prefs pattern, generalized for one field: skip when already
  # synced (idempotent, mtime-stable), .bak before rewrite, seed the whole
  # file on first run (deckcraft's serde tolerates partial files).
  syncScript = pkgs.writeShellScript "deckcraft-sync-brightness" ''
    set -euo pipefail
    JQ=${pkgs.jq}/bin/jq
    ui="${config.home.homeDirectory}/.config/deckcraft/ui.json"

    if [ -f "$ui" ]; then
      current=$("$JQ" -r '.brightness // empty' "$ui" 2>/dev/null) || {
        echo "[deckcraft] SKIP: ui.json unreadable"
        exit 0
      }
      if [ "$current" = "${brightness}" ]; then
        echo "[deckcraft] UNCHANGED"
        exit 0
      fi
      cp "$ui" "$ui.bak.$(date +%s)"
      "$JQ" --slurpfile new ${seedJson} '. * $new[0]' "$ui" > "$ui.tmp"
    else
      mkdir -p "$(dirname "$ui")"
      cp ${seedJson} "$ui.tmp"
    fi
    mv "$ui.tmp" "$ui"
    echo "[deckcraft] APPLIED brightness=${brightness}"
  '';
in
{
  imports = [ ../../shared/options/appearance.nix ];

  home.packages = [ deckcraft ];

  xdg.mimeApps.defaultApplications = {
    "application/x-deckcraft" = dc;
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = dc;
    "application/vnd.openxmlformats-officedocument.presentationml.template" = dc;
    "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = dc;
  };

  home.activation.deckcraftAppearance = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${syncScript}
  '';
}
