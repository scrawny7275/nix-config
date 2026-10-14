# modules/user/shell/starship.nix
{
  programs.starship = {
    enable = true;
    enableFishIntegration = false;
    settings.command_timeout = 10000;
  };
}
