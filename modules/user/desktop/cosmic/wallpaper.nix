# modules/user/desktop/cosmic/wallpaper.nix
{ cosmicLib, homeDirectory }:

let
  inherit (cosmicLib.cosmic) mkRON;
in
[
  {
    output = "all";
    source = mkRON "enum" {
      variant = "Path";
      value = [ "${homeDirectory}/Pictures/wall/desktop/nix-d-nord-blue.png" ];
    };
    filter_by_theme = true;
    rotation_frequency = 300;
    filter_method = mkRON "enum" "Lanczos";
    scaling_mode = mkRON "enum" "Zoom";
    sampling_method = mkRON "enum" "Alphanumeric";
  }
]
