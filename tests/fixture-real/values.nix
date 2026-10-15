# tests/fixture-real/values.nix — fixture simulating the private override:
# "real" shape with fully generic values (no secrets; public-safe fixture).
{
  real = true;
  userName = "fixture-user";
  fullName = "Fixture User";
  domain = "example.invalid";
  workUser = "fixture-user";
  workEmail = "fixture@example.invalid";
  pacUrl = null;
  proxyHosts = [ ];
  noProxy = [ ];
  extraHosts = { };
  registries = [ ];
  containersDns = [ ];
  vpnRemote = null;
  vpnAltIp = null;
  sshIdentities = { };
  coursierRepositories = "ivy2Local|central";
  coursierRepositoriesToolchain = "ivy2Local|central";
  nexus = null;
  nexusMirrorKeys = [ ];
  sbtRepoMode = "default-only";
  sbtRepositories = [ ];
}
