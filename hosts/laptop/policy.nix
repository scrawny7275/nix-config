# hosts/laptop/policy.nix
# Pure data. No function arguments.
#
# This is the PUBLIC base policy. When the private `private` input is active
# (--override-input private path:$HOME/nix-config-private) and ships its own
# policy.nix, the private adapter replaces this file's policy entirely
# (see modules/system/private.nix + modules/user/private.nix).
# TODO: If this is replaced it wouldn't need a declared strcuct for validate the icoming cas?
{
  javaTrustStorePassword = "changeit";

  noProxyDomains = [
    "localhost"
    "127.0.0.1"
  ];

  cas = {
    # Private CAs are injected by the private input's policy.nix.
    # Example shape:
    # private = {
    #   enable = true;
    #   certificate = <path-to-pem>;
    #   installName = "private-ca.pem";
    # };
  };
}
