# modules/user/desktop/x11.nix
{ pkgs, ... }:

{
  # X11 DPI & cursor
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  # Symlink the actual cursor theme to ~/.icons where X11 finds it
  home.file.".icons/Bibata-Modern-Classic".source =
    "${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic";

  home.sessionVariables = {
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    # XCURSOR_THEME = "Bibata-Modern-Classic";
    # XCURSOR_SIZE = "24";
  };

  # Fallback for apps that don't read env vars
  home.file.".icons/default/index.theme".text = ''
    [icon theme]
    Inherits=Bibata-Modern-Classic
  '';
}
