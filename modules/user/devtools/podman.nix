# modules/user/devtools/podman.nix
# Program for managing pods, containers and container images
{ config, lib, pkgs, ... }:

let
  v = config.modules.private.values;
in
{
  home.packages = with pkgs; [
    podman-compose # Implementation of docker-compose with podman backend
    skopeo # Command line utility for various operations on container images and image repositories
  ];

  home.shellAliases = {
    docker = "podman";
    "docker-compose" = "podman-compose";
  };

  services.podman = {
    enable = true;

    settings = {
      # Private/insecure registries come from the private private input
      # (stub: none). DNS likewise — needed to resolve internal mirror domains.
      registries.insecure = v.registries;
      containers = {
        dns_servers = v.containersDns;
        log_driver = "json-file"; # Keep the same log driver as Docker
        log_size_max = 10485760; # 10m = 10485760 bytes. Prevents container logs from growing forever.
      };
    };
  };
}
