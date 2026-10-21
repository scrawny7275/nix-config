# modules/user/app/wordcraft.nix
{ lib, pkgs, ... }:

let
  wordcraft = pkgs.callPackage ../../../pkgs/wordcraft { };

  # Default handler for the word-processing family (user decision
  # 2026-10-20). mkDefault: the generic xdg module's plain entries and host
  # overrides (modules.user.desktop.xdg.extraDefaultApplications) win.
  wc = lib.mkDefault "ai.storyteller.wordcraft.desktop";
in
{
  home.packages = [ wordcraft ];

  # The packaged binary is wrapped with WORDCRAFT_WAYLAND=1 (see pkgs/wordcraft):
  # native Wayland on every launch path — the X11 path opens a full-monitor-size
  # window that niri renders edge-to-edge ("fullscreen"). Native Wayland also
  # renders sharper text under fractional scaling, at the cost of file
  # drag-and-drop. Escape hatch: run .wordcraft-wrapped directly.

  # Word-processing formats only: wordcraft's desktop file also declares
  # text/plain, text/html, text/markdown and text/x-tex — those stay on the
  # central editor/browser roles (no hijack).
  xdg.mimeApps.defaultApplications = {
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = wc;
    "application/vnd.ms-word.document.macroEnabled.12" = wc;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = wc;
    "application/vnd.ms-word.template.macroEnabled.12" = wc;
    "application/msword" = wc;
    "application/msword-template" = wc;
    "application/vnd.oasis.opendocument.text" = wc;
    "application/rtf" = wc;
    "text/rtf" = wc;
  };
}
