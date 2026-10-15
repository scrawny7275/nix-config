# modules/user/desktop/cosmic/default.nix
{
  config,
  cosmicLib,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  upkgs = import inputs.unstable { inherit (pkgs.stdenv.hostPlatform) system; };
  inherit (cosmicLib.cosmic) mkRON;

  appearance = import ./appearance.nix { inherit cosmicLib; };
  panels = import ./panels.nix { inherit cosmicLib; };
  apps = import ./apps.nix { inherit cosmicLib; };
  wallpaper = import ./wallpaper.nix { inherit cosmicLib; inherit (config.home) homeDirectory; };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      cosmic-ext-applet-netspeed = final.callPackage ../../../../pkgs/cosmic-ext-applet-netspeed {
        crane = inputs.crane;
      };
    })
    (final: prev: {
      inherit (upkgs)
        cosmic-comp
        cosmic-applets
        cosmic-app-library
        cosmic-bg
        cosmic-edit
        cosmic-files
        cosmic-greeter
        cosmic-icons
        cosmic-idle
        cosmic-launcher
        cosmic-notifications
        cosmic-osd
        cosmic-panel
        cosmic-player
        cosmic-randr
        cosmic-screenshot
        cosmic-session
        cosmic-settings
        cosmic-settings-daemon
        cosmic-store
        cosmic-term
        cosmic-workspaces-epoch
        xdg-desktop-portal-cosmic
        ;
    })
  ];

  home.packages = with pkgs; [ cosmic-ext-applet-netspeed ];

  imports = [
    inputs.cosmic-manager.homeManagerModules.cosmic-manager
    ../../app/wlogout
    ./portal.nix
  ];

  home.file.".local/share/applications/io.github.user.logout-action.desktop".text = ''
    [Desktop Entry]
    Name=⏻
    Exec=wlogout --buttons-per-row 6
    Icon=com.system76.CosmicAppletPower-symbolic
    Type=Application
    Terminal=false
  '';

  home.file.".local/share/applications/io.github.user.logout.desktop".text = ''
    [Desktop Entry]
    Name=⏻
    Exec=cosmic-panel-button io.github.user.logout-action
    Icon=com.system76.CosmicAppletPower-symbolic
    Type=Application
    X-CosmicApplet=true
  '';

  wayland.desktopManager.cosmic = {
    enable = true;

    compositor = {
      active_hint = true;
      autotile = true;
      autotile_behavior = mkRON "enum" "PerWorkspace";
      focus_follows_cursor = true;
      edge_snap_threshold = 10;
      xkb_config = {
        rules = "";
        model = "pc105";
        layout = "latam";
        variant = "";
        options = mkRON "optional" "terminate:ctrl_alt_bksp";
        repeat_delay = 600;
        repeat_rate = 25;
      };
    };

    panels = panels.panels;
    inherit appearance;
    wallpapers = wallpaper;

    configFile = {
      "com.system76.CosmicTheme.Mode" = {
        version = 1;
        entries.is_dark = true;
      };

      # Master frosted-glass toggle (v1)
      "com.system76.CosmicTheme.Dark.Builder" = {
        version = 1;
        entries.is_frosted = true;
      };

      "com.system76.CosmicAppletBattery" = {
        version = 1;
        entries.show_percentage = true;
      };
    };
  };

  xdg.configFile = {
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v2/frosted_panel".text = "true";
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v2/frosted_applets".text = "true";
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v2/frosted_system_interface".text = "true";
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v2/frosted_windows".text = "true";
  };

  programs = apps;
}
