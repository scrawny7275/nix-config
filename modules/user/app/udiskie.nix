# modules/user/app/udiskie.nix
# Removable disk automounter using udisks2 over D-Bus.
# Requires services.udisks2.enable = true in NixOS system config.
{ pkgs, ... }:

{
  services.udiskie = {
    enable = true;
    automount = false;
    notify = true;
    tray = "auto";
    settings = {
      program_options = {
        udisks_version = 2;
      };
    };
  };
}
