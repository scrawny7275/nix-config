# modules/user/app/tide-island.nix
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  tide-island = pkgs.callPackage ../../../pkgs/tide-island { };

  makeTideIpc =
    name: cmd:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.quickshell ];
      text = ''
        exec quickshell -p ${tide-island}/share/tide-island ipc call tide ${cmd}
      '';
    };

  niriCfg = config.modules.user.desktop.niri;

in
{
  home.packages = with pkgs; [
    tide-island
    quickshell
    (makeTideIpc "tide-launcher" "toggleApplicationLauncher")
    (makeTideIpc "tide-notifications" "toggleNotificationCenter")
    (makeTideIpc "tide-control-center" "toggleControlCenter")
    brightnessctl
    gammastep
    cava
    imagemagick
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
  };

  # TODO: systemd service isn't working
  # systemd.user.services.tide-island = {
  #   Unit = {
  #     Description = "Tide Island";
  #     After = [ "default.target" ];
  #   };
  #   Service = {
  #     Type = "simple";
  #     # Wait until WAYLAND_DISPLAY is available, then start
  #     ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -n \"$WAYLAND_DISPLAY\" ]; do sleep 1; done'";
  #     ExecStart = "${tide-island}/bin/tide-island";
  #     Restart = "on-failure";
  #     RestartSec = 3;
  #   };
  #   Install.WantedBy = [ "default.target" ];
  # };

  xdg.configFile."tide-island/userconfig.json".text = builtins.toJSON {
    general = {
      position = "top-center";
      autostart = false;
    };
  };

  modules.user.desktop.niri.extraKdlConfig = [
    (inputs.niri.lib.kdl.plain "Mod+W" [
      (inputs.niri.lib.kdl.leaf "spawn" [ "tide-launcher" ])
    ])
    (inputs.niri.lib.kdl.plain "Mod+N" [
      (inputs.niri.lib.kdl.leaf "spawn" [ "tide-notifications" ])
    ])
    (inputs.niri.lib.kdl.plain "Mod+X" [
      (inputs.niri.lib.kdl.leaf "spawn" [ "tide-control-center" ])
    ])
  ];
}
