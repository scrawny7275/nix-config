# modules/user/desktop/dconf.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cosmic-icons # Keep if other apps still reference it, or remove
    pop-icon-theme
    bibata-cursors
    adw-gtk3
    gsettings-desktop-schemas
  ];

  dconf.enable = true;
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = "Yaru-dark";
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = 24;
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":close";
    };
  };

  home.sessionVariables = {
    GTK_DECORATION_LAYOUT = ":close";
    GTK_CSD = "0";
  };
}
