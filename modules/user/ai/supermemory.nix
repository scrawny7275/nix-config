# modules/user/ai/supermemory.nix
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.user.ai.supermemory;
  pkg = pkgs.callPackage ../../../pkgs/supermemory { };

  secretName =
    if cfg.mode == "local" then "api_keys/supermemory_local" else "api_keys/supermemory_cloud";

  baseUrl =
    if cfg.mode == "local" then
      "http://localhost:${toString cfg.port}"
    else
      "https://api.supermemory.ai";
in
{
  options.modules.user.ai.supermemory = {
    enable = mkEnableOption "Supermemory memory engine + opencode-supermemory plugin (complements context-mode)";

    mode = mkOption {
      type = types.enum [
        "local"
        "cloud"
        "off"
      ];
      default = "local";
      description = ''
        local: run the self-hosted supermemory-server binary and point the
          opencode-supermemory plugin at it. Data stays on this machine.
          The server generates its API key on first boot (see dataDir/api-key);
          store it as api_keys/supermemory_local via sops.
        cloud: use the hosted platform via the same plugin.
          Requires an api_keys/supermemory_cloud secret (console.supermemory.ai).
        off: disable the plugin entirely (context-mode only).
      '';
    };

    port = mkOption {
      type = types.port;
      default = 6767;
      description = ''
        HTTP port for the local server. Note: upstream binds 0.0.0.0
        (no bind-address knob in v0.0.8); treat as LAN-reachable.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "${config.xdg.dataHome}/supermemory";
      description = "Persistent data directory (encrypted graph DB, api-key file, model cache).";
    };

    maxMemory = mkOption {
      type = types.str;
      default = "3G";
      description = ''
        Hard memory cap for the local supermemory-server (systemd MemoryMax).
        Prevents runaway memory growth from ONNX embedding operations.
        The server previously peaked at 27 GB without a cap on a 30 GB system.
      '';
    };

    llm = {
      baseURL = mkOption {
        type = types.str;
        default = "http://127.0.0.1:20128/v1";
        description = ''
          OpenAI-compatible endpoint used for memory extraction/summaries.
          Default is the local OmniRoute gateway with auto routing, i.e. the
          extraction model follows your free-provider pool ("auto").
        '';
      };

      model = mkOption {
        type = types.str;
        default = "auto";
        description = "Model ID sent to llm.baseURL for extraction tasks.";
      };

      apiKey = mkOption {
        type = types.str;
        default = "free";
        description = "API key sent to llm.baseURL (OmniRoute free pool needs no real key).";
      };
    };

    plugin = {
      similarityThreshold = mkOption {
        type = types.float;
        default = 0.55;
        description = "Min similarity (0-1) for memory retrieval in opencode-supermemory.";
      };

      maxMemories = mkOption {
        type = types.ints.positive;
        default = 5;
        description = "Max memories injected per request by opencode-supermemory.";
      };
    };
  };

  config = mkMerge [
    # Local backend: binary + data dir + local API-key secret declaration.
    (mkIf (cfg.enable && cfg.mode == "local") {
      sops.secrets."api_keys/supermemory_local".mode = "0600";

      # Ensure the host data directory exists and is writable before the server starts.
      home.activation.supermemoryDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${cfg.dataDir}"
        $DRY_RUN_CMD chmod 700 $VERBOSE_ARG "${cfg.dataDir}" 2>/dev/null || true
      '';

      systemd.user.services.supermemory = {
        Unit = {
          Description = "Supermemory local memory engine";
          After = [
            "basic.target"
            "omniroute.service"
          ];
          # Prevent restart loops: if the service fails 3 times within
          # 5 minutes (e.g. OOM kill from exceeding MemoryMax), systemd
          # stops trying. Check `systemctl --user status supermemory`
          # and fix the root cause before restarting manually.
          StartLimitBurst = 3;
          StartLimitIntervalSec = 300;
        };

        Service = {
          Type = "simple";
          Environment = [
            "SUPERMEMORY_NO_PROMPT=1"
            "PORT=${toString cfg.port}"
            "SUPERMEMORY_DATA_DIR=${cfg.dataDir}"
            "OPENAI_BASE_URL=${cfg.llm.baseURL}"
            "OPENAI_MODEL=${cfg.llm.model}"
            "OPENAI_API_KEY=${cfg.llm.apiKey}"
            "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
          ];
          ExecStart = "${pkg}/bin/supermemory-server";
          Restart = "on-failure";
          RestartSec = "5";

          # Resource limits — prevents the server from consuming all system
          # memory when multiple opencode sessions trigger concurrent ONNX
          # embedding operations (previously peaked at 27 GB on 30 GB system).
          MemoryHigh = "2G";
          MemoryMax = cfg.maxMemory;
          CPUQuota = "200%";
          IOWeight = 50;
        };

        Install.WantedBy = [ "default.target" ];
      };
    })

    # Cloud backend: only the hosted API-key secret declaration.
    # NOTE: switching local -> cloud leaves the old user unit file behind;
    # stop it once manually: systemctl --user stop supermemory
    (mkIf (cfg.enable && cfg.mode == "cloud") {
      sops.secrets."api_keys/supermemory_cloud".mode = "0600";
    })

    # Plugin config for opencode-supermemory (local + cloud).
    # Rendered at activation via sops-nix so the API key never lands in the Nix store.
    (mkIf (cfg.enable && cfg.mode != "off") {
      sops.templates."opencode/supermemory.jsonc" = {
        path = "${config.xdg.configHome}/opencode/supermemory.jsonc";
        mode = "0600";
        content = builtins.toJSON {
          apiKey = config.sops.placeholder.${secretName};
          baseUrl = baseUrl;
          similarityThreshold = cfg.plugin.similarityThreshold;
          maxMemories = cfg.plugin.maxMemories;
          injectProfile = true;
        };
      };
    })
  ];
}
