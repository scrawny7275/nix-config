# modules/user/nix/nix-your-shell.nix
{
  programs.nix-your-shell = {
    enable = true;
    enableFishIntegration = true;
    nix-output-monitor.enable = true; # Pipe through nix-output-monitor for prettier builds
  };
}
