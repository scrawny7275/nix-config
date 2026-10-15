# modules/user/shell/zsh/default.nix
{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "docker-compose"
        "docker"
        "git"
        "python"
        "man"
      ];

      theme = "dst";
      # theme = "agnoster";
    };

    initContent = ''
      bindkey '^f' autosuggest-accept
      ${pkgs.any-nix-shell} zsh --info-right | source /dev/stdin
    '';

    history = {
      size = 10000;
      save = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      extended = true;
    };

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -lah";
      la = "ls -lAh";
      grep = "grep --color=auto";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [ oh-my-zsh ];

  imports = [ ./p10k.nix ];
}
