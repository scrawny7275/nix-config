# modules/user/networking/alpaca.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.alpaca;

  pythonWithCrypto = pkgs.python3.withPackages (ps: [ ps.pycryptodome ]);

  ntlmHashScript = pkgs.writeShellScript "alpaca-ntlm-hash" ''
        export PATH="${lib.makeBinPath [ pkgs.coreutils ]}"
        set -euo pipefail
        PASSWORD=$(tr -d '\n' < "$1")
        printf '%s' "$PASSWORD" | ${pythonWithCrypto}/bin/python3 -c "
    from Crypto.Hash import MD4
    import sys
    pw = sys.stdin.buffer.read().decode('utf-8')
    h = MD4.new(pw.encode('utf-16le'))
    print(h.hexdigest())
    "
  '';
in
{
  options.services.alpaca = {
    enable = lib.mkEnableOption "alpaca proxy server (PAC + NTLM)";

    package = lib.mkPackageOption pkgs "alpaca-proxy" { };

    pacUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://proxy.corporation.com/proxy.pac";
      description = "PAC file URL. Alpaca evaluates this for every request.";
    };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to listen on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3128;
      description = "Port to listen on.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      example = "user.name";
      description = "NTLM username.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      example = "example.invalid";
      description = "NTLM domain.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "-q" ];
      description = "Extra flags passed to alpaca.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.pacUrl != null;
        message = "services.alpaca.pacUrl must be set.";
      }
    ];

    sops.secrets."cntlm/password".mode = "0600";

    home.packages = [ cfg.package ];

    systemd.user.services.alpaca = {
      Unit = {
        Description = "Alpaca Proxy (PAC + NTLM)";
        After = [
          "network.target"
          "sops-nix.service"
        ];
        Requires = [ "sops-nix.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart =
          let
            alpacaLaunch = pkgs.writeShellScript "alpaca-launch" ''
              export PATH="${lib.makeBinPath [ pkgs.coreutils ]}"
              set -euo pipefail
              HASH=$(${ntlmHashScript} "${config.sops.secrets."cntlm/password".path}")
              export NTLM_CREDENTIALS="${cfg.username}@${cfg.domain}:$HASH"
              exec ${lib.getExe cfg.package} \
                -l ${lib.escapeShellArg cfg.listen} \
                -p ${toString cfg.port} \
                -C ${lib.escapeShellArg cfg.pacUrl} \
                ${lib.escapeShellArgs cfg.extraArgs}
            '';
          in
          "${alpacaLaunch}";
        Restart = "always";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
