# modules/user/app/db-visualizer.nix
# Universal database tool
{ pkgs, ... }:

{
  home.packages = [ (pkgs.dbvisualizer.override { openjdk17 = pkgs.jdk21; }) ];
}
