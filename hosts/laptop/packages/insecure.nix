# hosts/laptop/packages/insecure.nix
{
  nixpkgs.config.permittedInsecurePackages = [ "ventoy-1.1.12" ];
}
