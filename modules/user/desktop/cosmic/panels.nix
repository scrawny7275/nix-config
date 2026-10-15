# modules/user/desktop/cosmic/panels.nix
{ cosmicLib }:

let
  inherit (cosmicLib.cosmic) mkRON;

  panelList = [
    {
      name = "Panel";
      anchor = mkRON "enum" "Top";
      anchor_gap = true;
      expand_to_edges = false;
      size = mkRON "enum" "XS";
      margin = 4;
      padding = 0;
      opacity = 0.7;
      background = mkRON "enum" "ThemeDefault";
      output = mkRON "enum" "All";
      plugins_center = mkRON "optional" [
        "com.system76.CosmicAppletTime"
      ];
      plugins_wings = mkRON "optional" (
        mkRON "tuple" [
          [ "com.system76.CosmicAppletStatusArea" ]
          [
            "com.system76.CosmicAppletAudio"
            "com.system76.CosmicAppletBluetooth"
            # "io.github.khanra17.cosmic-ext-applet-netspeed"
            "com.system76.CosmicAppletNetwork"
            "com.system76.CosmicAppletBattery"
            "com.system76.CosmicAppletNotifications"
            # "com.system76.CosmicAppletPower"
            "io.github.user.logout"
          ]
        ]
      );
      autohide = mkRON "optional" null
      # {
      # wait_time = 1000;
      # transition_time = 200;
      # handle_size = 4;
      # unhide_delay = 200;
      # }
      ;
    }
  ];
in
{
  panels = panelList;
}
