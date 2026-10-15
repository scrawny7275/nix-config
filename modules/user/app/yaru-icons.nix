# modules/user/app/yaru-icons.nix
{ pkgs, ... }:

let
  yaru-icons = pkgs.callPackage ../../../pkgs/yaru-icons { };
in
{
  home.packages = [ yaru-icons ];
}
