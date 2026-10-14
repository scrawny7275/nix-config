# modules/user/desktop/niri/hmwindow-rules.nix
{
  window-rules = [
    # All windows rounded corners
    {
      # No matches means applies to all windows
      geometry-corner-radius = {
        top-left = 12;
        top-right = 12;
        bottom-left = 12;
        bottom-right = 12;
      };
      clip-to-geometry = true;
      tiled-state = true;
    }

    # Niri dialog rounded
    {
      matches = [ { app-id = "niri-confirmation"; } ];
      geometry-corner-radius = {
        top-left = 25;
        top-right = 25;
        bottom-left = 25;
        bottom-right = 25;
      };
      clip-to-geometry = true;
    }

    # Firefox Picture-in-Picture
    {
      matches = [
        {
          app-id = "^org\.mozilla\.firefox$";
          title = "^Picture-in-Picture$";
        }
      ];
      open-floating = true;
    }
  ];

  layer-rules = [
    {
      matches = [ { namespace = "^awww-daemon$"; } ];
      place-within-backdrop = true;
    }
  ];
}
