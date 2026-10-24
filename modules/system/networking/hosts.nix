# modules/system/networking/hosts.nix
{ config, lib, ... }:

{
  networking.hosts = {
    "127.0.1.1" = [ config.networking.hostName ];
  }
  # Static hosts come from the private input (stub: none).
  // config.modules.private.values.extraHosts;
}
