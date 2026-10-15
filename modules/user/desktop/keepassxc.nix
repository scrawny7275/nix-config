# modules/user/desktop/keepassxc.nix
{ pkgs, ... }:

{
  xdg.autostart.enable = true; # has to be enabled in order for {option}`programs.keepassxc.autostart` to be effective.
  # xdg.autostart.entries = [ "${pkgs.keepassxc}/share/applications/keepassxc.desktop" ];

  programs.keepassxc.enable = true;
  programs.keepassxc.autostart = false;
}
