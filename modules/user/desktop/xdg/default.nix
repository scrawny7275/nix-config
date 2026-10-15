# modules/user/desktop/xdg/default.nix
{ pkgs, ... }:

let
  portal = import ./portal.nix { inherit pkgs; };
  mimeApps = import ./mimeApps.nix;
in
{
  xdg = {
    portal = portal;
    mime.enable = true;
    mimeApps = mimeApps;
  };
}
