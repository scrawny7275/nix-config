# modules/user/wayvid.nix
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  wayvid = inputs.wayvid.packages.${pkgs.stdenv.hostPlatform.system}.wayvid.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ [
      pkgs.openssl
      pkgs.dbus
    ];
  });
in
{
  # Install wayvid (contains both GUI and CLI binaries)
  home.packages = [ wayvid ];

  # Systemd user service for wayvid
  systemd.user.services.wayvid = {
    Unit = {
      Description = "Wayvid video wallpaper engine";
      Documentation = "https://github.com/YangYuS8/wayvid";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${wayvid}/bin/wayvid-gui";
      ExecStop = "${wayvid}/bin/wayvid-ctl stop";
      Restart = "on-failure";
      RestartSec = 3;

      # Resource limits
      MemoryMax = "512M";
      CPUQuota = "50%";
    };

    # This automatically adds it to graphical-session.target
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Alternative: If you need to ensure graphical-session wants it explicitly
  # Use this instead of modifying the target directly:
  systemd.user.targets.graphical-session = {
    Unit = {
      Wants = [ "wayvid.service" ];
    };
  };

  # Create wrapper script for easy control
  home.file.".local/bin/wallpaper" = {
    text = ''
      #!/usr/bin/env bash
      case "$1" in
        set|apply)
          wayvid-ctl apply "$2" ''${3:+--output "$3"}
          ;;
        pause|resume|stop|status)
          wayvid-ctl "$1"
          ;;
        gui)
          wayvid-gui &
          ;;
        *)
          echo "Usage: wallpaper {set <file> [output]|pause|resume|stop|status|gui}"
          exit 1
          ;;
      esac
    '';
    executable = true;
  };

  # Add to PATH
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Ensure config directory exists
  home.file.".config/wayvid/.keep".text = "";

  # Session variables
  home.sessionVariables = {
    WAYVID_CONFIG_DIR = "${config.xdg.configHome}/wayvid";
  };
}
