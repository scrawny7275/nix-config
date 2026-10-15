# modules/user/devtools/direnv.nix
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # caches flake shells
  };
}
