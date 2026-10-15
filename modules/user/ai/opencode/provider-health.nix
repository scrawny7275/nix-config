# modules/user/ai/opencode/provider-health.nix
# Wiring-only module for scripts/health/provider-matrix.sh (the single-copy classifier).
# The script is referenced by RUNTIME path, not nix-copied: hand-run and unit-run must
# execute the same bytes (a store copy would silently run a stale version after edits —
# the round-3 sparring verdict). Deliberate deviation from the writeShellScriptBin
# convention (freellmapi/metals-repair); justified by the script being dual-use.
#
# Units:
#   provider-health.service/.timer  — narrow scope every 20 min; transitions land in the
#                                     user journal (stdout) + tide-island via notify-send
#                                     (requires quickshell-notifyd, enabled in niri module).
#   provider-health-daily.*          — 08:00 daily checkout: full matrix + 24h digest.
#                                     Persistent=true → catch-up on wake/boot; NO WakeSystem
#                                     (laptop never wakes itself for probes).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.ai.opencode.providerHealth;
  script = "${config.home.homeDirectory}/nix-config/scripts/health/provider-matrix.sh";
  # hermetic PATH for the oneshot units; XDG_STATE_HOME is NOT set in systemd user env
  # (verified) — the script falls back to ~/.local/state.
  probePath = lib.makeBinPath [
    pkgs.bash
    pkgs.curl
    pkgs.coreutils
    pkgs.gnused
    pkgs.gawk
    pkgs.gnugrep
    pkgs.python3
    pkgs.util-linux # flock
    pkgs.libnotify
  ];
in
{
  options.modules.user.ai.opencode.providerHealth.enable =
    lib.mkEnableOption "provider/model health timers (narrow 20-min probe + 08:00 daily matrix)";

  config = lib.mkIf cfg.enable {
    systemd.user.services.provider-health = {
      Unit = {
        Description = "opencode provider health — narrow probe (kimi/glm/control)";
        # no After=sops-nix: the script reads secrets via resolved file paths from
        # opencode.json, which are rendered before the session starts.
      };

      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${probePath}" ];
        ExecStart = "${pkgs.bash}/bin/bash ${script} --scope=narrow";
        # worst case: 130s probes + 310s kimi confirm, parallel → ~450s
        TimeoutStartSec = 900;
      };
    };

    systemd.user.timers.provider-health = {
      Unit.Description = "opencode provider health — narrow probe every 20 min";

      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "20min";
        RandomizedDelaySec = "60s";
        Persistent = true;
      };

      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.provider-health-daily = {
      Unit.Description = "opencode provider health — daily matrix + 24h digest";

      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${probePath}" ];
        ExecStart = "${pkgs.bash}/bin/bash ${script} --daily";
        # worst case: parallel 130s matrix + digest
        TimeoutStartSec = 1800;
      };
    };

    systemd.user.timers.provider-health-daily = {
      Unit.Description = "opencode provider health — daily checkout at 08:00";

      Timer = {
        OnCalendar = "*-*-* 08:00:00";
        RandomizedDelaySec = "15min";
        Persistent = true; # missed while off/suspended → runs at next wake/boot
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
