# modules/user/app/simpmusic.nix
{ pkgs, ... }:

let
  simpmusic = pkgs.callPackage ../../../pkgs/simpmusic { };
in
{
  home.packages = [ simpmusic ];
}
