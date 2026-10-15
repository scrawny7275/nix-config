# modules/user/terminal/kitty.nix
{ pkgs, ... }:

{
  programs.kitty = {
    enable = true; # Enable the kitty module

    # Configuration options map directly to Kitty's kitty.conf format
    # Use underscores instead of hyphens for option names
    settings = {
      # Basic settings
      font_family = "JetBrainsMono Nerd Font"; # Example font, adjust as needed
      font_size = 12;

      background_opacity = 0.5;
      background_blur = 1;

      shell = "${pkgs.zsh}/bin/zsh";

      # Colors (using a built-in theme as an example, or define your own)
      # background = "#1e1e2e";
      # foreground = "#cdd6f4";
      # selection_background = "#585b70";
      # selection_foreground = "#cdd6f4";
      # color0 = "#45475a";   # Black
      # color8 = "#585b70";   # Bright Black (Gray)
      # color1 = "#f38ba8";   # Red
      # color9 = "#f38ba8";   # Bright Red
      # ... define all 16 colors (0-15) as needed

      # Window settings
      # window_padding_width = 10;
      # window_border_width = 1;
      # window_title_template = "{app_id}"; # Customize window title

      # Keyboard shortcuts (example: map F1 to show help)
      # map = [
      #   "f1 show_documentation"
      #   "ctrl+shift+v paste_from_clipboard"
      #   "ctrl+shift+c copy_to_clipboard"
      # ]; # Use a list if you have multiple maps

      # Mouse settings
      # confirm_os_window_close = 0; # Disable confirmation on close

      # Performance
      # repaint_delay = 10;
      # input_delay = 3;
      # sync_to_monitor = true;
    };

    # Optional: Add keybindings (alternative to settings.map)
    # keybindings = {
    #   "f1" = "show_documentation";
    #   "ctrl+shift+v" = "paste_from_clipboard";
    #   "ctrl+shift+c" = "copy_to_clipboard";
    # };

    # Optional: Add command line options passed every time kitty starts
    # commandLineOptions = [ "--config" "/path/to/alternative.conf" ]; # Usually not needed if using settings

    # Optional: Enable or manage the kitty shell integration script
    # shellIntegration = {
    #   enable = true; # Enable shell integration (requires compatible shell)
    #   # Modes like 'enabled', 'disabled', 'injections-only' might be available depending on HM version
    # };
  };
}
