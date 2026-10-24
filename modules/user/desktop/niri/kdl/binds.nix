# modules/user/desktop/niri/kdl/binds.nix
{ config, inputs }:

let
  inherit (inputs.niri.lib.kdl)
    plain
    leaf
    flag
    ;

  extraBinds = config.modules.user.desktop.niri.extraKdlConfig or [ ];

  # Define your keybindings here
  binds = plain "binds" (
    [
      # Show hotkey overlay
      (plain "Mod+Space" [ (flag "show-hotkey-overlay") ])

      # Suggested binds for running programs
      (plain "Mod+T" [ (leaf "spawn" [ "foot" ]) ])
      # (plain "Mod+D" [ (leaf "spawn" [ "fuzzel" ]) ])
      # (plain "Super+Alt+L" [ (leaf "spawn" [ "swaylock" ]) ])
      (plain "Mod+E" [ (leaf "spawn" [ "cosmic-files" ]) ])
      # (plain "Mod+W" [
      #   (leaf "spawn" [
      #     "wofi"
      #     "--show"
      #     "drun"
      #   ])
      # ])
      # (plain "Mod+W" [ (leaf "spawn" [ "cosmic-launcher" ]) ])

      # Close window
      (plain "Mod+Q" [ (flag "close-window") ])

      # Focus and movement
      (plain "Mod+H" [ (flag "focus-column-left") ])
      (plain "Mod+L" [ (flag "focus-column-right") ])
      (plain "Mod+Ctrl+H" [ (flag "move-column-left") ])
      (plain "Mod+Ctrl+L" [ (flag "move-column-right") ])
      (plain "Mod+J" [ (flag "focus-window-down") ])
      (plain "Mod+K" [ (flag "focus-window-up") ])
      (plain "Mod+Ctrl+J" [ (flag "move-window-down") ])
      (plain "Mod+Ctrl+K" [ (flag "move-window-up") ])

      # Workspace switching
      (plain "Mod+Page_Down" [ (flag "focus-workspace-down") ])
      (plain "Mod+Page_Up" [ (flag "focus-workspace-up") ])
      (plain "Mod+Ctrl+Page_Down" [ (flag "move-column-to-workspace-down") ])
      (plain "Mod+Ctrl+Page_Up" [ (flag "move-column-to-workspace-up") ])

      # Layout actions
      (plain "Mod+F" [ (flag "maximize-column") ])
      (plain "Mod+V" [ (flag "toggle-window-floating") ])
      (plain "Mod+Shift+V" [ (flag "switch-focus-between-floating-and-tiling") ])
      (plain "Mod+R" [ (flag "switch-preset-column-width") ])
      (plain "Mod+C" [ (flag "center-column") ])

      # Screenshot
      (plain "Print" [ (flag "screenshot") ])

      # Quit Niri (shows confirmation dialog)
      (plain "Mod+Shift+E" [ (flag "quit") ])

      # Power off monitors
      # (plain "Mod+Shift+P" [ (flag "power-off-monitors") ])
      (plain "Mod+Shift+P" [
        (leaf "spawn" [
          "wlogout"
          "--buttons-per-row"
          "6"
        ])
      ])

      # Volume controls (standard wpctl for PipeWire)
      (plain "XF86AudioRaiseVolume" [
        (leaf "spawn" [
          "wpctl"
          "set-volume"
          "@DEFAULT_AUDIO_SINK@"
          "3%+"
        ])
      ])

      (plain "XF86AudioLowerVolume" [
        (leaf "spawn" [
          "wpctl"
          "set-volume"
          "@DEFAULT_AUDIO_SINK@"
          "1%-"
        ])
      ])

      (plain "XF86AudioMute" [
        (leaf "spawn" [
          "wpctl"
          "set-mute"
          "@DEFAULT_AUDIO_SINK@"
          "toggle"
        ])
      ])

      # Microphone mute (standard wpctl)
      (plain "XF86AudioMicMute" [
        (leaf "spawn" [
          "wpctl"
          "set-mute"
          "@DEFAULT_AUDIO_SOURCE@"
          "toggle"
        ])
      ])

      # Brightness controls (standard brightnessctl)
      (plain "XF86MonBrightnessUp" [
        (leaf "spawn" [
          "brightnessctl"
          "set"
          "+3%"
        ])
      ])

      (plain "XF86MonBrightnessDown" [
        (leaf "spawn" [
          "brightnessctl"
          "set"
          "1%-"
        ])
      ])

      # --- Multimedia Keys (Volume and Brightness with Notifications) ---

      # Replace the entire multimedia section with:

      # Volume controls (integrated OSD)
      # (plain "XF86AudioRaiseVolume" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--output-volume"
      #     "raise"
      #   ])
      # ])

      # (plain "XF86AudioLowerVolume" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--output-volume"
      #     "lower"
      #   ])
      # ])

      # (plain "XF86AudioMute" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--output-volume"
      #     "mute-toggle"
      #   ])
      # ])

      # Microphone mute (optional OSD)
      # (plain "XF86AudioMicMute" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--input-volume"
      #     "mute-toggle"
      #   ])
      # ])

      # Brightness controls (integrated OSD)
      # (plain "XF86MonBrightnessUp" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--brightness"
      #     "raise"
      #   ])
      # ])

      # (plain "XF86MonBrightnessDown" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--brightness"
      #     "lower"
      #   ])
      # ])

      # Caps Lock indicator (optional but recommended)
      # (plain "Caps_Lock" [
      #   (leaf "spawn" [
      #     "swayosd-client"
      #     "--caps-lock"
      #   ])
      # ])
      # --- End Multimedia Keys ---

      # --- NEW: Window Resizing (Column Width Adjustment) ---
      # Grow/Shrink the focused column width by 10%
      # (Use negative values to shrink)
      (plain "Mod+Minus" [ (leaf "set-column-width" "-5%") ]) # Shrink column width
      (plain "Mod+Plus" [ (leaf "set-column-width" "+5%") ]) # Grow column width

      # Example: Set column width to specific percentages
      (plain "Mod+Shift+1" [ (leaf "set-column-width" "100%") ]) # Set to 25% of screen width
      (plain "Mod+Shift+2" [ (leaf "set-column-width" "50%") ]) # Set to 50% of screen width
      (plain "Mod+Shift+3" [ (leaf "set-column-width" "75%") ]) # Set to 75% of screen width

      # Example: Adjust column width by fixed pixel amounts (logical pixels)
      # (plain "Mod+Ctrl+Minus" [ (leaf "set-column-width" "-50") ]) # Decrease by 50 pixels
      # (plain "Mod+Ctrl+Equal" [ (leaf "set-column-width" "+50") ]) # Increase by 50 pixels

      # --- End Window Resizing ---

      # (plain "Mod+T" [ (leaf "spawn" "cosmic-term") ])
      # (plain "Mod+D" [ (leaf "spawn" "cosmic-launcher") ])
      # (plain "Mod+Shift+D" [ (leaf "spawn" "cosmic-app-library") ])
      # (plain "Mod+Alt+L" [ (leaf "spawn" "cosmic-greeter") ])
    ]
    ++ extraBinds
  );

in
# Return the list containing the 'binds' node
[ binds ]
