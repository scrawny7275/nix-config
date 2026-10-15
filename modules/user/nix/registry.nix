# modules/user/nix/registry.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  nix.registry = {
    dotfiles = {
      from = {
        type = "indirect";
        id = "dotfiles";
      };
      to = {
        type = "git";
        url = "file://${config.home.homeDirectory}/nix-config";
      };
    };
  };
}
