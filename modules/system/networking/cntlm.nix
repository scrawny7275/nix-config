# modules/system/networking/cntlm.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  passwordFilePath = "/run/secrets/cntlm/password";
  # Employer values from the private input (stub/public when not supplied).
  # See modules/system/employer.nix.
  inherit (config.modules.private) values enable;
in
{
  options.services.cntlm.passwordFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Path to a file containing the NTLM password.";
  };

  config.users.users.cntlm = lib.mkIf config.services.cntlm.enable {
    group = "cntlm";
    isSystemUser = true;
  };

  config.users.groups.cntlm = lib.mkIf config.services.cntlm.enable { };

  config.sops.secrets."cntlm/password" =
    lib.mkIf (config.services.cntlm.enable && config.services.cntlm.passwordFile != null)
      {
        sopsFile = ../../../secrets/laptop.yaml;
        path = passwordFilePath;
        mode = "0600";
        owner = "cntlm";
      };

  config.services.cntlm = {
    enable = enable;
    username = values.workUser;
    domain = values.domain;
    passwordFile = passwordFilePath;
    proxy = values.proxyHosts;
    noproxy = values.noProxy;
    port = [ 3128 ];
    password = "placeholder";
  };

  # Create /run/cntlm via tmpfiles (runs as root)
  config.systemd.tmpfiles.rules =
    lib.mkIf (config.services.cntlm.enable && config.services.cntlm.passwordFile != null)
      [
        "d /run/cntlm 0750 cntlm cntlm -"
      ];

  # Override systemd service when passwordFile is used
  config.systemd.services.cntlm =
    lib.mkIf (config.services.cntlm.enable && config.services.cntlm.passwordFile != null)
      {
        serviceConfig = {
          # Run ExecStartPre as root (User= is set to cntlm in original module, but we need root for the script)
          ExecStartPre =
            "+"
            + pkgs.writeShellScript "cntlm-gen-config" ''
                      mkdir -p /run/cntlm
                      cat > /run/cntlm/cntlm.conf << EOF
              Username ${config.services.cntlm.username}
              Domain ${config.services.cntlm.domain}
              Password $(cat "${config.services.cntlm.passwordFile}")
              ${lib.optionalString (
                config.services.cntlm.netbios_hostname != ""
              ) "Workstation ${config.services.cntlm.netbios_hostname}"}
              ${lib.concatMapStrings (p: "Proxy ${p}\n") config.services.cntlm.proxy}
              ${lib.optionalString (
                config.services.cntlm.noproxy != [ ]
              ) "NoProxy ${lib.concatStringsSep ", " config.services.cntlm.noproxy}"}
              ${lib.concatMapStrings (port: "Listen ${toString port}\n") config.services.cntlm.port}
              ${config.services.cntlm.extraConfig}
              EOF
                      chmod 600 /run/cntlm/cntlm.conf
                      chown cntlm:cntlm /run/cntlm/cntlm.conf
            '';
          ExecStart = lib.mkForce "${pkgs.cntlm}/bin/cntlm -U cntlm -c /run/cntlm/cntlm.conf -v -f";
        };
      };
}
