# modules/user/desktop/gtk.nix
{ pkgs, ... }:

{
  gtk = {
    enable = true;
    iconTheme = {
      name = "Yaru-dark";
      package = pkgs.callPackage ../../../pkgs/yaru-icons { };
    };

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = ":close";
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = ":close";
    };
  };

  home.sessionVariables.GTK_THEME = "adw-gtk3-dark";
}
