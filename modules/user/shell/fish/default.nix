# modules/user/shell/fish/deafult.nix
{ config, pkgs, ... }:

let
  hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
in
{
  # imports = [ ../starship.nix ];

  programs.fish = {
    enable = true;

    plugins = [
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env;
      }
      {
        name = "bobthefish";
        src = pkgs.fishPlugins.bobthefish;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish;
      }
    ];

    # Source Home Manager's POSIX session variables into Fish
    # shellInit = ''
    #   fenv source ${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh
    # '';
    shellInit = builtins.readFile ./hm-session-vars.fish;

    interactiveShellInit = ''
      set -g fish_greeting ""
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source
    '';
  };
}
