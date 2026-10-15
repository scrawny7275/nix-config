# modules/shared/options/proxy.nix
{ lib, ... }:

{
  options.proxy = {
    enable = lib.mkEnableOption "central proxy configuration" // {
      default = false;
      description = "Enable centralized proxy settings across modules.";
    };

    http = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HTTP proxy URL (e.g., http://localhost:3128).";
    };

    https = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HTTPS proxy URL.";
    };

    socks = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SOCKS proxy URL.";
    };

    pacUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "PAC file URL.";
    };

    noProxy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Hosts/domains to bypass proxy.";
    };
  };
}
