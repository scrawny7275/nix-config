# modules/user/desktop/xdg/portal.nix
{ pkgs, ... }:

{
  enable = true;
  # xdgOpenUsePortal = true;
  config.common.default = [
    "cosmic"
    "gtk"
    "gnome"
  ];
  extraPortals = with pkgs; [
    xdg-desktop-portal-cosmic
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
  ];
  configPackages = with pkgs; [
    xdg-desktop-portal-cosmic
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
  ];
}
