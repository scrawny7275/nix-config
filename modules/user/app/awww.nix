# modules/user/app/awww.nix
{ inputs, pkgs, ... }:

let
  awwwPkg = inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww;
in
{
  home.packages = [ awwwPkg ];

  systemd.user.services.awww = {
    Unit = {
      Description = "Awww wallpaper daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${awwwPkg}/bin/awww-daemon";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = "WAYLAND_DISPLAY=wayland-1";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
