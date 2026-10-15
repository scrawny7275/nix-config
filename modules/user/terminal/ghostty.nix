# modules/user/terminal/ghostty.nix
{
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    settings = {
      # theme = "ayu";
      background-opacity = 0.5;
    };
  };
}
