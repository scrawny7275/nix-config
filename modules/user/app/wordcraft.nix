# modules/user/app/wordcraft.nix
{ pkgs, ... }:

let
  wordcraft = pkgs.callPackage ../../../pkgs/wordcraft { };
in
{
  home.packages = [ wordcraft ];

  # The packaged binary is wrapped with WORDCRAFT_WAYLAND=1 (see pkgs/wordcraft):
  # native Wayland on every launch path — the X11 path opens a full-monitor-size
  # window that niri renders edge-to-edge ("fullscreen"). Native Wayland also
  # renders sharper text under fractional scaling, at the cost of file
  # drag-and-drop. Escape hatch: run .wordcraft-wrapped directly.
}
