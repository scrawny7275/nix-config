# modules/user/app/eww/service.nix
# Start eww as part of the graphical session
{ config, ... }:

{
  systemd.user.services.eww-splash = {
    Unit = {
      Description = "Eww desktop splash widget";
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.programs.eww.package}/bin/eww daemon --no-daemonize";
      ExecStartPost = "${config.programs.eww.package}/bin/eww open splash";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
