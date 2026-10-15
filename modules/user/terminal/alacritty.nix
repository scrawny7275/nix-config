# modules/user/terminal/alacritty.nix
{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true; # Enable the alacritty module

    # Configuration options map to Alacritty's alacritty.toml format
    settings = {
      # Basic settings
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font"; # Example font, adjust as needed
          style = "Regular"; # Or "Medium", "Bold", etc., depending on the specific font file
        };
        size = 12.0; # Font size is a float
      };

      # Window settings
      window = {
        opacity = 0.7; # Background opacity (0.0 transparent, 1.0 opaque)
        # Note: Alacritty's native blur support is limited compared to Kitty's background_blur.
        # Some compositors (like Hyprland, Niri potentially in the future) handle blur.
        # Alacritty itself doesn't have a direct 'blur' setting like Kitty.
        padding = {
          x = 30; # Horizontal padding
          y = 10; # Vertical padding
        };
        # dynamic_padding = true; # Add extra padding to center the terminal content
        # decorations = "full"; # "full", "none", "transparent" (if supported by compositor)
        # startup_mode = "Windowed"; # "Windowed", "Maximized", "Fullscreen"
        # title = "Alacritty"; # Default window title
        # class = { instance = "Alacritty"; general = "Alacritty"; }; # WM_CLASS values
      };

      # Shell settings
      terminal.shell = {
        program = "${pkgs.fish}/bin/fish"; # Use the fish installed by Nix
        # args = [ "--login" ]; # Optional: start zsh as a login shell
      };

      # Colors (using a built-in theme as an example, or define your own under 'colors')
      # Alacritty uses a different color scheme structure than Kitty.
      # You can define the entire 'colors' section or use a 'color_scheme' import if available.
      # Here's an example defining a basic colors section (using placeholder colors):
      # colors = {
      #   primary = {
      #     background = "#1e1e2e";
      #     foreground = "#cdd6f4";
      #   };
      #   cursor = {
      #     text = "#1e1e2e";
      #     cursor = "#cdd6f4";
      #   };
      #   # Define normal and bright ANSI colors (0-15)
      #   normal = {
      #     black = "#45475a";
      #     red = "#f38ba8";
      #     green = "#a6e3a1";
      #     yellow = "#f9e2af";
      #     blue = "#89b4fa";
      #     magenta = "#f5c2e7";
      #     cyan = "#94e2d5";
      #     white = "#bac2de";
      #   };
      #   bright = {
      #     black = "#585b70"; # Gray
      #     red = "#f38ba8";
      #     green = "#a6e3a1";
      #     yellow = "#f9e2af";
      #     blue = "#89b4fa";
      #     magenta = "#f5c2e7";
      #     cyan = "#94e2d5";
      #     white = "#a6adc8";
      #   };
      # };
      # Alternatively, you might be able to import a pre-defined theme:
      # import = [ "~/.config/alacritty/themes/catppuccin-mocha.toml" ]; # Example

      # Keybindings (Example mappings, structure is different from Kitty)
      # Keybindings are defined under the 'key_bindings' list.
      # Each binding is an object with 'key', 'mods', 'action', and potentially 'chars'.
      # Common actions include "Paste", "Copy", "Quit", running commands, etc.
      # Example bindings:
      # key_bindings = [
      #   # Copy/Paste (Standard)
      #   { key = "V"; mods = "Control|Shift"; action = "Paste"; }
      #   { key = "C"; mods = "Control|Shift"; action = "Copy"; }
      #   # Quit (Example)
      #   { key = "Q"; mods = "Control|Shift"; action = "Quit"; }
      #   # Toggle Fullscreen (Example)
      #   { key = "F11"; mods = "None"; action = "ToggleFullscreen"; }
      #   # Create a new window (Example)
      #   { key = "N"; mods = "Control|Shift"; action = "SpawnNewInstance"; }
      #   # Send specific characters (Example for Ctrl+Shift+T)
      #   # { key = "T"; mods = "Control|Shift"; chars = "\u0014"; } # Sends Ctrl+T
      # ];

      # Mouse settings (Example)
      # mouse = {
      #   # hide_when_typing = true; # Hide mouse cursor while typing
      #   # url = {
      #   #   launcher = { program = "xdg-open"; args = []; }; # Program to open URLs
      #   #   modifiers = "None"; # Modifiers required to click URLs
      #   # };
      # };

      # Scrolling settings (Example)
      # scrolling = {
      #   # history = 10000; # Number of lines to keep in scrollback
      #   # multiplier = 3; # Multiplier for scrolling speed
      # };

      # Live config reload (usually enabled by default)
      # live_config_reload = true;
    };

    # Optional: Explicitly set the shell integration script path if needed (usually handled automatically if enabled)
    # shellIntegration = {
    #   enable = true; # Enable shell integration (requires compatible shell like zsh with zsh-defer or similar)
    # };
  };
}
