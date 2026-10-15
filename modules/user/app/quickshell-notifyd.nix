# modules/user/app/quickshell-notifyd.nix
# Headless notification daemon: owns org.freedesktop.Notifications, displays
# nothing, so tide-island's dbus-monitor mirror (backend/SystemServices.cpp:
# watches method_call interface=org.freedesktop.Notifications member=Notify)
# actually receives traffic. Without an owner, notify-send fails with
# ServiceUnknown and no bus message ever dispatches (verified 2026-09-30).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.app.quickshell-notifyd;
in
{
  options.modules.user.app.quickshell-notifyd.enable =
    lib.mkEnableOption "headless quickshell NotificationServer daemon (feeds tide-island's notification mirror)";

  config = lib.mkIf cfg.enable {
    xdg.configFile."quickshell-notifyd/shell.qml".text = ''
      import Quickshell
      import Quickshell.Services.Notifications

      ShellRoot {
        NotificationServer {
          onNotification: notification => notification.dismiss()
        }
      }
    '';

    systemd.user.services.quickshell-notifyd = {
      Unit = {
        Description =
          "Headless quickshell notification daemon (org.freedesktop.Notifications owner; displays nothing)";
        After = [ "default.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.quickshell} -p ${config.xdg.configHome}/quickshell-notifyd";
        Restart = "on-failure";
        RestartSec = "5";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
