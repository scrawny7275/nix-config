# modules/user/desktop/niri-wallpaper.nix
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = config.programs.niri-wallpaper;

  niri-wallpaper = pkgs.stdenv.mkDerivation {
    pname = "niri-wallpaper";
    version = "unstable-2024-01-01";

    src = pkgs.fetchgit {
      url = "https://codeberg.org/vyn/niri-wallpaper.git";
      rev = "refs/heads/main";
      sha256 = "sha256-YnMNwbHFD/PIrT1WToha4d7XDMU8+wSC1tirP7uNWhc=";
      fetchSubmodules = true;
    };

    nativeBuildInputs = with pkgs; [
      cmake
      gcc
    ];

    installPhase = ''
      install -Dm755 niri-wallpaper $out/bin/niri-wallpaper
    '';
  };

  niri-wallpaper-wrapped = pkgs.writeShellScriptBin "niri-wallpaper" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.swaybg
        pkgs.swaylock
        pkgs.imagemagick
        inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
      ]
    }:$PATH"

    exec ${niri-wallpaper}/bin/niri-wallpaper \
      --path-swaybg ${pkgs.swaybg}/bin/swaybg \
      --path-swaylock ${pkgs.swaylock}/bin/swaylock \
      --path-magick ${pkgs.imagemagick}/bin/magick \
      --path-awww ${inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww}/bin/awww \
      "$@"
  '';

in
{
  options.programs.niri-wallpaper = {
    enable = lib.mkEnableOption "niri-wallpaper";

    wallpapersDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing wallpapers";
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Interval between changes in seconds";
    };

    output = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Specific output (null for all)";
    };

    random = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Random order (false for alphabetical)";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = niri-wallpaper-wrapped;
      description = "The niri-wallpaper package";
      internal = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.swaybg
      pkgs.swaylock
      pkgs.imagemagick
      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
    ];

    systemd.user.services.niri-wallpaper = {
      Unit = {
        Description = "Niri Wallpaper";
        After = [
          "graphical-session.target"
          "niri.service"
          "awww.service"
        ];
        Requires = [ "awww.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/niri-wallpaper ${cfg.wallpapersDir} -i ${toString cfg.interval}";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = "WAYLAND_DISPLAY=wayland-1";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # ── Activation: immediate kill + restart ──
    home.activation.niriWallpaperTakeover = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Kill cosmic-bg immediately
      $DRY_RUN_CMD pkill -9 -f cosmic-bg 2>/dev/null || true

      # Restart services
      $DRY_RUN_CMD systemctl --user daemon-reload 2>/dev/null || true
      $DRY_RUN_CMD systemctl --user restart awww 2>/dev/null || true
      $DRY_RUN_CMD sleep 2
      $DRY_RUN_CMD systemctl --user restart niri-wallpaper 2>/dev/null || true
    '';
  };
}
