# modules/user/desktop/gnome-keyring.nix
{ config, ... }:

{
  home.sessionVariables = {
    GNOME_KEYRING_CONTROL = "${
      config.home.sessionVariables.XDG_RUNTIME_DIR or "/run/user/$(id -u)"
    }/keyring";
  };
  services.gnome-keyring.enable = true;
}
