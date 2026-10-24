# modules/user/desktop/niri/cosmic-ext/default.nix
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = config.programs.cosmic-ext-niri;

  script = pkgs.writeScript "niri-cosmic.sh" ''
    #!${pkgs.runtimeShell}
    ${builtins.readFile ./niri-cosmic.sh}
  '';

  # cosmic-ext-alternative-startup (not yet in nixpkgs)
  cosmic-ext-alternative-startup = pkgs.rustPlatform.buildRustPackage {
    pname = "cosmic-ext-alternative-startup";
    version = "unstable-2024-11-24";
    src = pkgs.fetchFromGitHub {
      owner = "drakulix";
      repo = "cosmic-ext-alternative-startup";
      rev = "8ceda00197c7ec0905cf1dccdc2d67d738e45417";
      hash = "sha256-0kqn3hZ58uQMl39XXF94yQS1EWmGIK45/JFTAigg/3M=";
    };
    cargoHash = "sha256-DeMkAG2iINGden0Up013M9mWDN4QHrF+FXoNqpGB+mg=";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.wayland
      pkgs.libxkbcommon
    ];
    meta.license = lib.licenses.gpl3Only;
  };

  # TTY launcher
  niri-cosmic = pkgs.writeShellApplication {
    name = "niri-cosmic";
    runtimeInputs = [
      pkgs.dbus
      pkgs.systemd
      pkgs.procps
    ];
    text = script;
  };

  bindsKdl = [
    ''Mod+T { spawn "cosmic-term"; }''
    ''Mod+D { spawn "cosmic-launcher"; }''
    ''Mod+Shift+D { spawn "cosmic-app-library"; }''
    ''Mod+Alt+L { spawn "cosmic-greeter"; }''
  ];

  bindsNix = {
    "Mod+T".action.spawn = "cosmic-term";
    "Mod+D".action.spawn = "cosmic-launcher";
    "Mod+Shift+D".action.spawn = "cosmic-app-library";
    "Mod+Alt+L".action.spawn = "cosmic-greeter";
  };

  # Extra spawn entries when polkit integration is requested
  # polkitSpawnsKdl = lib.optional cfg.polkit ''
  #   spawn-at-startup "cosmic-osd"
  # '';

  # polkitSpawnsNix = lib.optionalAttrs cfg.polkit {
  #   spawn-at-startup = [ "cosmic-osd" ];
  # };

in
{
  options.programs.cosmic-ext-niri = {
    enable = lib.mkEnableOption "COSMIC desktop ecosystem on niri";

    package = lib.mkOption {
      type = lib.types.package;
      default = niri-cosmic;
      description = "The COSMIC-on-niri session launcher package.";
    };

    alternativeStartupPackage = lib.mkOption {
      type = lib.types.package;
      default = cosmic-ext-alternative-startup;
      description = "The cosmic-ext-alternative-startup package.";
    };

    polkit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use the COSMIC polkit agent (cosmic-osd) instead of an external one.
        When enabled, do not run gnome-polkit or lxqt-policykit-agent in the
        same session or authentication dialogs will race/crash.
      '';
    };

    sessionVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        XDG_CURRENT_DESKTOP = "Cosmic";
        XDG_SESSION_DESKTOP = "cosmic";
        XDG_SESSION_TYPE = "wayland";
        XCURSOR_THEME = "Cosmic";
        _JAVA_AWT_WM_NONREPARENTING = "1";
        GDK_BACKEND = "wayland,x11";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland;xcb";
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        QT_ENABLE_HIGHDPI_SCALING = "1";
      };
      description = "Environment variables exported by the COSMIC-on-niri session.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [
        # pkgs.cosmic-panel
        # pkgs.cosmic-osd
        # pkgs.cosmic-workspaces
        # pkgs.cosmic-term
        # pkgs.cosmic-launcher
        # pkgs.cosmic-app-library
        # pkgs.cosmic-files
        # pkgs.cosmic-greeter
        # pkgs.cosmic-applets
        # pkgs.cosmic-notifications
        # pkgs.cosmic-settings
        # pkgs.cosmic-randr
        # pkgs.cosmic-screenshots
      ];
      description = "Additional COSMIC packages to install.";
    };

    useKdlConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the parent niri config uses KDL format.";
    };
  };

  config = lib.mkIf cfg.enable {

    home.packages =
      with cfg;
      [
        package
        alternativeStartupPackage
      ]
      ++ cfg.extraPackages;

    # On niri, systemd user service activation sometimes lags behind compositor readiness;
    # explicit spawn ensures the agent is available immediately
    programs.niri = lib.mkIf config.programs.niri.enable (

      if cfg.useKdlConfig then
        {
          config = [
            ''spawn-at-startup "${cfg.alternativeStartupPackage}/bin/cosmic-ext-alternative-startup"''
          ]
          ++ bindsKdl
          # ++ polkitSpawnsKdl
          ;
        }
      else
        {
          settings = {
            spawn-at-startup = [
              "${cfg.alternativeStartupPackage}/bin/cosmic-ext-alternative-startup"
            ]
            # ++ lib.optional cfg.polkit "cosmic-osd"
            ;
          }
          // bindsNix
          # // polkitSpawnsNix
          ;
        }
    );
  };
}
