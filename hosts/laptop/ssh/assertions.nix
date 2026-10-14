# hosts/laptop/ssh/assertions.nix
# Generic identity assertions — identities come from the private input, so these
# assert on the *matrix*, not on hardcoded names.
{ config, lib, ... }:

let
  ids = config.modules.private.values.sshIdentities;
  managed = builtins.concatMap (
    group: builtins.filter (e: (e.managedSecret or null) != null) (builtins.attrValues ids.${group})
  ) (builtins.attrNames ids);
in
{
  assertions = [
    # Every managed key must be deployed mode 0600 by sops-nix.
    {
      assertion = builtins.all (
        e: (config.sops.secrets."ssh/${e.managedSecret}".mode or "") == "0600"
      ) managed;
      message = "All SSH private keys must be managed by sops-nix with mode 0600";
    }
  ];
}
