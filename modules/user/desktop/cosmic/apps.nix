# modules/user/desktop/cosmic/apps.nix
{ cosmicLib }:

let
  inherit (cosmicLib.cosmic) mkRON;
in
{
  cosmic-applibrary.enable = true;

  cosmic-files = {
    enable = true;
    settings = {
      show_details = false;
      tab = {
        folders_first = true;
        icon_sizes = {
          list = 500;
          grid = 500;
        };
        show_hidden = true;
        view = mkRON "enum" "Grid";
      };
    };
  };
}
