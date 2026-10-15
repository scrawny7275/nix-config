# hosts/laptop/packages/unfree.nix
{ pkgs, ... }:

{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) (import ./unfree-list.nix);
}
