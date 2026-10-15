# modules/system/shell.nix
{ pkgs, ... }:

{
  programs.zsh.enable = true;
  programs.zsh.promptInit = ''
    ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
  '';

  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source
  '';

  environment.shells = with pkgs; [
    fish
    zsh
  ];

  users.defaultUserShell = pkgs.fish;
}
