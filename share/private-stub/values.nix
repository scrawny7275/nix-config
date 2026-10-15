# share/private-stub/values.nix
# Public stub values for the `employer` flake input. The real working environment is
# supplied by a private local flake input (never published):
#
#   sudo nixos-rebuild switch --flake .#laptop --override-input private path:$HOME/nix-config-private
#   home-manager switch --flake .#<user> --override-input private path:$HOME/nix-config-private
#
# `real` MUST stay false here — the employer adapter asserts on it, so enabling
# employer integration against this stub is a loud eval failure, not a silent one.
{
  real = false;

  userName = "user";
  fullName = "Example User";

  domain = "example.invalid";
  workUser = "user";
  workEmail = "user@example.invalid";

  pacUrl = null;
  proxyHosts = [ ];
  noProxy = [ ];
  extraHosts = { };
  registries = [ ];
  containersDns = [ ];

  vpnRemote = null;
  vpnAltIp = null;

  coursierRepositories = "ivy2Local|central";
  coursierRepositoriesToolchain = "ivy2Local|central";
  nexus = null;
  nexusMirrorKeys = [ ];
  sbtRepoMode = "default-only";
  sbtRepositories = [ ];

  sshIdentities = { };
}
