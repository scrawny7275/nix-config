# modules/user/desktop/cosmic/portal.nix
{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Wrap cosmic-settings-daemon to skip greeter sync
  cosmic-settings-daemon-wrapped = pkgs.writeShellScriptBin "cosmic-settings-daemon" ''
    # Run daemon, suppressing greeter sync error
    ${pkgs.cosmic-settings-daemon}/bin/cosmic-settings-daemon 2>/dev/null
  '';
in
{
  # Only if using COSMIC in niri (not full COSMIC session)
  config = lib.mkIf config.wayland.desktopManager.cosmic.enable {
    # Ensure COSMIC session variables are set for portals
    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Cosmic";
      XDG_SESSION_DESKTOP = "cosmic";
      XDG_SESSION_TYPE = "wayland";
      GTK_USE_PORTAL = "1";
    };

    # COSMIC settings daemon (required for portal)
    systemd.user.services.cosmic-settings-daemon = {
      Unit = {
        Description = "COSMIC Settings Daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cosmic-settings-daemon-wrapped}/bin/cosmic-settings-daemon";
        Restart = "on-failure";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ coreutils ])}"
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # Schemas for GTK portal
    home.packages = with pkgs; [
      gsettings-desktop-schemas
      gtk4
    ];
  };
}
