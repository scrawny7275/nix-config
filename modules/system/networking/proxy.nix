# modules/system/networking/proxy.nix
{ config, lib, ... }:

{
  networking = lib.mkMerge [
    (lib.mkIf (config.proxy.enable && config.proxy.http != null) {
      proxy.default = config.proxy.http;
    })
  ];

  environment.sessionVariables = lib.mkIf config.proxy.enable {
    http_proxy = lib.optionalString (config.proxy.http != null) config.proxy.http;
    https_proxy = lib.optionalString (config.proxy.https != null) config.proxy.https;
    socks_proxy = lib.optionalString (config.proxy.socks != null) config.proxy.socks;
    no_proxy = lib.optionalString (config.proxy.noProxy != [ ]) (builtins.concatStringsSep "," config.proxy.noProxy);
  };
}
