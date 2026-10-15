# modules/suer/nix/nix-index.nix
{
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
}
