# modules/user/ai/freellmapi.nix
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.user.ai.freellmapi;
in
{
  options.modules.user.ai.freellmapi = {
    enable = mkEnableOption "FreeLLMAPI local free-tier LLM aggregator (Podman rootless)";

    port = mkOption {
      type = types.port;
      default = 3001;
      description = "HTTP port for the router API + dashboard (bound to 127.0.0.1).";
    };

    dataDir = mkOption {
      type = types.str;
      default = "${config.xdg.dataHome}/freellmapi";
      description = "Persistent data directory (SQLite DB, encryption key file).";
    };

    image = mkOption {
      type = types.str;
      default = "ghcr.io/tashfeenahmed/freellmapi:latest";
      description = "Container image to pull and run.";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."api_keys/freellmapi_encryption".mode = "0600";

    # Render the container env file via sops template so the decrypted key
    # never appears in the podman argv (i.e. not visible in `ps` /
    # `systemctl status` / `/proc/<pid>/cmdline`). The template file is
    # mode 0600 on the sops tmpfs — same exposure profile as the source
    # secret itself.
    sops.templates."freellmapi/env" = {
      path = "${config.xdg.runtimeDir or "/run/user/1000"}/freellmapi-env";
      mode = "0600";
      content = ''
        ENCRYPTION_KEY=${config.sops.placeholder."api_keys/freellmapi_encryption"}
      '';
    };

    home.activation.freellmapiDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${cfg.dataDir}"
      $DRY_RUN_CMD chmod 755 $VERBOSE_ARG "${cfg.dataDir}" 2>/dev/null || true
    '';

    systemd.user.services.freellmapi = {
      Unit = {
        Description = "FreeLLMAPI free-tier LLM aggregator (Podman)";
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
        ExecStartPre = [ "-${pkgs.podman}/bin/podman rm -f freellmapi" ];
        ExecStart = pkgs.writeShellScript "freellmapi-start" ''
          set -euo pipefail
          env_file="${config.sops.templates."freellmapi/env".path}"
          [ -s "$env_file" ] || { echo "freellmapi: env file missing or empty: $env_file" >&2; exit 1; }
          exec ${pkgs.podman}/bin/podman run \
            --name freellmapi \
            --rm \
            --replace \
            --pull newer \
            --userns=keep-id \
            --memory 1g \
            --cpus 2 \
            -p 127.0.0.1:${toString cfg.port}:3001 \
            -e NODE_ENV=production \
            -e PORT=3001 \
            --env-file "$env_file" \
            -v "${cfg.dataDir}:/app/server/data" \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop -t 10 freellmapi";
        ExecStopPost = "-${pkgs.podman}/bin/podman rm -f freellmapi";
        Restart = "on-failure";
        RestartSec = "5";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
