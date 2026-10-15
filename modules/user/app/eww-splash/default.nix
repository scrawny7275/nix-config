{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.eww-splash;

  quotesFile = ./quotes.txt;

  randomQuoteScript = pkgs.writeShellScript "eww-random-quote" ''
    ${pkgs.coreutils}/bin/shuf -n1 ${quotesFile}
  '';

  cycleQuoteScript = pkgs.writeShellScript "eww-cycle-quote" ''
    set -euo pipefail

    quotes_file="${quotesFile}"
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/eww-quote-index"

    if [[ ! -f "$state_file" ]]; then
      ${pkgs.coreutils}/bin/echo 0 > "$state_file"
    fi

    total_lines=$(${pkgs.coreutils}/bin/wc -l < "$quotes_file")
    current_index=$(${pkgs.coreutils}/bin/cat "$state_file")

    line_num=$((current_index + 1))
    ${pkgs.gnused}/bin/sed -n "''${line_num}p" "$quotes_file"

    next_index=$(((current_index + 1) % total_lines))
    ${pkgs.coreutils}/bin/echo "$next_index" > "$state_file"
  '';

  quoteScript = if cfg.randomQuotes then randomQuoteScript else cycleQuoteScript;

  ewwYuck = lib.pipe (builtins.readFile ./eww.yuck) [
    (lib.replaceStrings [ "@interval@" ] [ cfg.interval ])
    (lib.replaceStrings [ "@quoteScript@" ] [ "${quoteScript}" ])
  ];
in
{
  options.programs.eww-splash = {
    enable = lib.mkEnableOption "eww splash widget";

    randomQuotes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, quotes are picked randomly on each interval. If false, they cycle sequentially.";
    };

    systemdService = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If true, manage the eww daemon via a systemd user service.
        Disable if you prefer to spawn it via Niri's spawn-at-startup.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "How often the quote rotates. Eww defpoll interval format (e.g. 5s, 1m, 1h).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.eww;
      description = "The eww package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.eww = {
      enable = true;
      package = cfg.package;
    };

    xdg.configFile = {
      "eww/eww.yuck".text = ewwYuck;
      "eww/eww.scss".source = ./eww.scss;
      "eww/quotes.txt".source = ./quotes.txt;
    };

    systemd.user.services.eww-splash = lib.mkIf cfg.systemdService {
      Unit = {
        Description = "Eww desktop splash widget";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/eww daemon --no-daemonize";
        ExecStartPost = "${cfg.package}/bin/eww open splash";
        Restart = "on-failure";
        RestartSec = 2;
        Environment = "WAYLAND_DISPLAY=wayland-1";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
