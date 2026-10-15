# hosts/laptop/proxy-options.nix
{ ... }:

{
  imports = [ ../../modules/shared/options/proxy.nix ];

  proxy = {
    enable = false;
    # Set the following to configure proxy per host:
    # http = "http://localhost:3128";
    # https = "http://localhost:3128";
    # socks = null;
    # pacUrl = null;
    # noProxy = [ "localhost" "127.0.0.1" ];
  };
}
