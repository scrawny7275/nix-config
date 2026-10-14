# modules/user/security/ssh.nix
{ lib, config, ... }:

let
  identities = config.security.ssh.identities or { };
in
{
  # Enable SSH agent for all hosts
  config.services.ssh-agent.enable = true;

  # Base SSH client config
  config.programs.ssh = {
    enable = true; # Enable the SSH client configuration
    enableDefaultConfig = false; # Prevents the default SSH config from being included
  };

  # Define the identities option
  options.security.ssh.identities = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.attrsOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption { type = lib.types.str; };
            hostname = lib.mkOption { type = lib.types.str; };
            user = lib.mkOption { type = lib.types.str; };
            keyPath = lib.mkOption { type = lib.types.path; };
            port = lib.mkOption {
              type = lib.types.int;
              default = 22;
            };

            proxy = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        }
      )
    );
    default = { };
    description = "SSH identity matrix per host";
  };

  # Generate the matchBlocks dynamically
  config.programs.ssh.settings =
    let
      flattenIdentities = builtins.concatMap (
        groupName:
        lib.mapAttrsToList (identityName: idData: {
          name = "${idData.host}-${identityName}";

          value = {
            host = "${idData.host}-${identityName}";
            hostname = idData.hostname;
            user = idData.user;
            port = idData.port;

            identityFile = [ idData.keyPath ];
            identitiesOnly = true;
            addKeysToAgent = "yes";
          }
          // lib.optionalAttrs (idData.proxy != null) {
            proxyCommand = idData.proxy;
          };
        }) identities.${groupName}
      ) (builtins.attrNames identities);
    in
    lib.listToAttrs flattenIdentities;
}
