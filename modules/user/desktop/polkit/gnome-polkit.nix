# modules/user/desktop/polkit/gnome-polkit.nix
{ pkgs, ... }:

{
  home.packages = [ pkgs.polkit_gnome ];

  systemd.user.services.polkit-agent-gnome = {
    Unit = {
      Description = "Gnome PolicyKit Authentication Agent";
      After = [ "graphical-session-pre.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-agent-helper-1";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
