# modules/user/app/escrcpy.nix
{ pkgs, ... }:

let
  escrcpy = pkgs.callPackage ../../../pkgs/escrcpy { };
in
{
  home.packages = [ escrcpy ];
}
