# hosts/laptop/ssh/default.nix
# SSH identities are data, supplied by the private private input's
# values.nix (sshIdentities matrix). Public stub = empty. Shape per entry:
#   { host; hostname; user; keyName; port ? 22; proxy ? null; managedSecret ? null }
# managedSecret = sops key name "ssh/<managedSecret>" delivering the key.
{ config, lib, ... }:

let
  ids = config.modules.private.values.sshIdentities;
  home = config.home.homeDirectory;

  flatten = builtins.concatMap (
    group: lib.mapAttrsToList (name: e: e // { inherit group name; }) ids.${group}
  ) (builtins.attrNames ids);

  managed = builtins.filter (e: (e.managedSecret or null) != null) flatten;
in
{
  # sops-delivered private keys for managed identities (generic secret names;
  # the real identity only exists in the private input).
  sops.secrets = lib.listToAttrs (
    map (e: {
      name = "ssh/${e.managedSecret}";
      value = {
        path = "${home}/.ssh/${e.keyName}";
        mode = "0600";
      };
    }) managed
  );

  # Host alias dynamic mappings (see modules/user/security/ssh.nix).
  security.ssh.identities = lib.mapAttrs (
    group: lib.mapAttrs (
      name: e: {
        inherit (e) host hostname user;
        port = e.port or 22;
        proxy = e.proxy or null;
        keyPath = "${home}/.ssh/${e.keyName}";
      }
    )
  ) ids;

  # TODO: re-enable and resolve assertion conflicts
  # imports = [ ./assertions.nix ];
}
