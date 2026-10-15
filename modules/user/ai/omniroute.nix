# modules/user/ai/omniroute.nix
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.user.ai.omniroute;
in
{
  options.modules.user.ai.omniroute = {
    enable = mkEnableOption "OmniRoute local AI gateway (Podman rootless)";

    # NOTE (2026-09-26, declarative fix after ses_f304 autopsy):
    # - provider_connections DB is EMPTY; past 402/403 errors came from the app's
    #   pre-wired keyless "OpenCode Free" (oc/*) catalog stub, which 403s by design
    #   through external proxies. Nothing to delete app-side.
    # - WAIVER (declarative constraint): OmniRoute's provider connections live in its
    #   internal SQLite DB (no declarative API); adding providers happens via the
    #   dashboard at http://127.0.0.1:20128 (Providers page; keys from sops:
    #   nvidia, openrouter, sambanova, cloudfare, gemini). Recorded exception.
    # - Memory: vendor FATAL-ERRORs V8 heap under long-context coding-agent traffic
    #   unless OMNIROUTE_MEMORY_MB≈8192 + ≥10g container; useless overhead while
    #   opencode talks to providers directly. Restore 8192/12g if quota-separation
    #   routing through OmniRoute is re-enabled (see providers.nix omniroute note).

    port = mkOption {
      type = types.port;
      default = 20128;
      description = "HTTP port for the gateway + dashboard.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "${config.xdg.dataHome}/omniroute";
      description = "Persistent data directory (DB, caches, keys).";
    };

    apiKey = mkOption {
      type = types.str;
      default = "free";
      description = ''
        Dummy API key sent to the local endpoint.
        OmniRoute's free pool does not authenticate, but OpenCode
        requires a non-empty key in its provider schema.
      '';
    };

    image = mkOption {
      type = types.str;
      default = "docker.io/diegosouzapw/omniroute:3.8.50";
      description = ''
        Container image to pull and run. Pinned tag (never :latest + --pull newer):
        upgrades happen by editing this value deliberately. Latest verified stable: 3.8.50.
      '';
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."api_keys/omnirouter".mode = "0600";

    # Ensure the host data directory exists and is writable before the container starts.
    home.activation.omnirouteDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${cfg.dataDir}"
      $DRY_RUN_CMD chmod 755 $VERBOSE_ARG "${cfg.dataDir}" 2>/dev/null || true
    '';

    systemd.user.services.omniroute = {
      Unit = {
        Description = "OmniRoute AI Gateway (Podman)";
        After = [
          "basic.target"
          "sops-nix.service"
        ];
      };

      Service = {
        Type = "simple";
        Environment = [
          "PODMAN_SYSTEMD_UNIT=%n"
          "XDG_RUNTIME_DIR=%t"
        ];
        ExecStartPre = [ "-${pkgs.podman}/bin/podman rm -f omniroute" ];
        ExecStart = pkgs.writeShellScript "omniroute-start" ''
          exec ${pkgs.podman}/bin/podman run \
            --name omniroute \
            --rm \
            --replace \
            --pull newer \
            --userns=keep-id \
            --memory 4g \
            --cpus 2 \
            -p ${toString cfg.port}:${toString cfg.port} \
            -e PORT=${toString cfg.port} \
            -e HOST=0.0.0.0 \
            -e DATA_DIR=/data \
            -e NODE_ENV=production \
            -e APP_LOG_TO_FILE=false \
            -e REQUIRE_API_KEY=false \
            -e OMNIROUTE_MEMORY_MB=4096 \
            -v "${cfg.dataDir}:/data" \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop -t 10 omniroute";
        ExecStopPost = "-${pkgs.podman}/bin/podman rm -f omniroute";
        Restart = "on-failure";
        RestartSec = "5";
      };

      Install.WantedBy = [ "default.target" ];

    };
  };
}
