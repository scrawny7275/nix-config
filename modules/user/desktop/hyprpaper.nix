# modules/user/desktop/hyprpaper.nix
{ pkgs, ... }:

{
  services.hyprpaper = {
    enable = true;

    # Configure settings for hyprpaper
    settings = {
      preload = [ "${pkgs.hyprland}/share/hypr/wall0.png" ]; # Example, verify path

      # Define how to apply the wallpaper to outputs
      # Replace 'eDP-1' with your actual monitor name (find with `hyprctl monitors`)
      # Use '*' for all monitors
      "*" = {
        # Or "*" for all outputs
        wallpaper = "${pkgs.hyprland}/share/hypr/wall0.png"; # Example path
        # Or use your specific path: wallpaper = ./path/to/your/wallpaper.png;
      };
    };
  };
}
