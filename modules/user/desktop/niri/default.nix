# modules/user/desktop/niri/hmdefault.nix
{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  cfg = config.modules.user.desktop.niri;

  hmToKdl = import ./hm-to-kdl.nix { inherit inputs lib; };

  settings =
    if cfg.useKdlConfig then
      import ./kdl/settings.nix { inherit inputs; }
    else
      import ./hm/settings.nix;

  binds =
    if cfg.useKdlConfig then
      import ./kdl/binds.nix { inherit config inputs; }
    else
      import ./hm/binds.nix;

  input =
    if cfg.useKdlConfig then import ./kdl/input.nix { inherit inputs; } else import ./hm/input.nix;

  baseWindowRules =
    if cfg.useKdlConfig then
      import ./kdl/window-rules.nix { inherit inputs; }
    else
      import ./hm/window-rules.nix;

  extraWindowRulesConverted =
    if cfg.useKdlConfig then hmToKdl.windowRulesToKdl cfg.extraWindowRules else cfg.extraWindowRules;

  windowRules =
    if cfg.useKdlConfig then
      baseWindowRules ++ extraWindowRulesConverted
    else
      baseWindowRules
      // {
        window-rules = (baseWindowRules.window-rules or [ ]) ++ extraWindowRulesConverted;
      };

  gestures =
    if cfg.useKdlConfig then
      import ./kdl/gestures.nix { inherit inputs; }
    else
      import ./hm/gestures.nix;

in
{
  imports = [
    inputs.niri.homeModules.niri
    ../mako.nix
    ../dconf.nix
    ../xdg
    ./cosmic-ext

    ../ags
    ../niri-wallpaper.nix
    ../../app/awww.nix
    ../../app/eww-splash
    ../../terminal/alacritty.nix
    ../../app/sunsetr
    ../../app/tide-island.nix
    ../../app/quickshell-notifyd.nix
    ../../app/thunar.nix
    ../polkit/plasma-polkit.nix
  ];

  options.modules.user.desktop.niri = {
    enable = lib.mkEnableOption "niri scrollable-tiling Wayland compositor";
    useKdlConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use KDL-based config instead of the standard Home Manager settings.";
    };
    extraKdlConfig = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      description = "Extra KDL nodes to append to the generated niri config.";
    };
    extraWindowRules = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = ''
        Extra window rules in Home Manager format (attrsets).
        App modules can contribute rules here; they are automatically
        translated to KDL when useKdlConfig = true.
      '';
    };
  };

  config = {
    nixpkgs.overlays = [ inputs.niri.overlays.niri ];

    programs.niri = {
      enable = true;
      package = pkgs.niri-unstable;
    }
    // (
      if cfg.useKdlConfig then
        {
          config = settings ++ binds ++ input ++ windowRules ++ gestures;
        }
      else
        {
          settings = settings // binds // input // windowRules // gestures;
        }
    );

    home.packages = with pkgs; [
      xwayland-satellite # xwayland support
      libnotify
      gawk
    ];

    # Enable the COSMIC-on-niri session launcher
    programs.cosmic-ext-niri.enable = false;

    modules.user.app.sunsetr.enable = true;
    modules.user.app.quickshell-notifyd.enable = true;

    home.sessionVariables = {
      WINIT_UNIX_BACKEND = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      CHROME_FLAGS = "--enable-features=PulseAudio --disable-features=AudioServiceSandbox";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      GTK_USE_PORTAL = "1";
    };

    programs.niri-wallpaper = {
      enable = false;
      wallpapersDir = "${config.home.homeDirectory}/Pictures/wall/single";
      interval = 3600;
      random = false;
    };

    programs.eww-splash = {
      enable = true;
      randomQuotes = false;
      interval = "30s";
      systemdService = true;
    };
  };
}
