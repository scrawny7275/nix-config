# modules/user/app/sunsetr.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.app.sunsetr;
  tomlFormat = pkgs.formats.toml { };

  sunsetrConfig = {
    backend = "auto";
    transition_mode = "geo";
    smoothing = true;
    startup_duration = 0.5;
    shutdown_duration = 0.5;
    night_temp = 3300;
    day_temp = 6500;
    night_gamma = 90;
    day_gamma = 100;
    update_interval = "auto";
    sunset = "19:00:00";
    sunrise = "06:00:00";
    transition_duration = 45;
  };

in
{
  options.modules.user.app.sunsetr = {
    enable = lib.mkEnableOption "sunsetr blue light filter for Wayland";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.sunsetr ];

    sops.secrets."sunsetr/geo" = {
      sopsFile = ./geo.toml.enc;
      format = "binary";
      path = "${config.xdg.configHome}/sunsetr/geo.toml";
      mode = "0400";
    };

    xdg.configFile."sunsetr/sunsetr.toml" = {
      source = tomlFormat.generate "sunsetr-config" sunsetrConfig;
      force = true;
    };

    systemd.user.services.sunsetr = {
      Unit = {
        Description = "Sunsetr color temperature daemon";
        After = [
          "sops-nix.service"
          "graphical-session.target"
          "niri.service"
        ];
        PartOf = [ "graphical-session.target" ];
        # Ensure niri is running (provides Wayland socket)
        Requires = [ "niri.service" ];
      };
      Service = {
        ExecStart = "${pkgs.sunsetr}/bin/sunsetr";
        Restart = "on-failure";
        RestartSec = 10;
        # Run inside niri's systemd scope to inherit WAYLAND_DISPLAY and Wayland socket
        Slice = "app.slice";
        Environment = lib.mkForce [
          "WAYLAND_DISPLAY=wayland-1"
          "XDG_RUNTIME_DIR=%t"
        ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
