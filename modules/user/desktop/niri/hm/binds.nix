# modules/user/desktop/niri/hm/binds.nix
{
  binds = {
    # Show hotkey overlay
    "Mod+Space".action = "show-hotkey-overlay";

    # Suggested binds for running programs
    "Mod+T".action.spawn = [ "foot" ];
    "Mod+E".action.spawn = [ "thunar" ];
    "Mod+W".action.spawn = [ "cosmic-launcher" ];

    # Layout actions
    "Mod+V".action = "toggle-window-floating";
    "Mod+Shift+V".action = "switch-focus-between-floating-and-tiling";
    "Mod+R".action = "switch-preset-column-width";

    # Screenshot
    "Print".action = "screenshot";

    # Quit Niri (shows confirmation dialog)
    "Mod+Shift+E".action.quit.skip-confirmation = false;

    # Power off monitors
    "Mod+Shift+P".action = "power-off-monitors";

    # Volume controls (standard wpctl for PipeWire)
    "XF86AudioRaiseVolume".action.spawn = [
      "wpctl"
      "set-volume"
      "@DEFAULT_AUDIO_SINK@"
      "3%+"
    ];

    "XF86AudioLowerVolume".action.spawn = [
      "wpctl"
      "set-volume"
      "@DEFAULT_AUDIO_SINK@"
      "1%-"
    ];

    "XF86AudioMute".action.spawn = [
      "wpctl"
      "set-mute"
      "@DEFAULT_AUDIO_SINK@"
      "toggle"
    ];

    # Microphone mute (standard wpctl)
    "XF86AudioMicMute".action.spawn = [
      "wpctl"
      "set-mute"
      "@DEFAULT_AUDIO_SOURCE@"
      "toggle"
    ];

    # Brightness controls (standard brightnessctl)
    "XF86MonBrightnessUp".action.spawn = [
      "brightnessctl"
      "set"
      "+3%"
    ];

    "XF86MonBrightnessDown".action.spawn = [
      "brightnessctl"
      "set"
      "1%-"
    ];

    # Window Resizing (Column Width Adjustment)
    "Mod+Minus".action.set-column-width = "-5%";
    "Mod+Plus".action.set-column-width = "+5%";

    # Set column width to specific percentages
    "Mod+Shift+1".action.set-column-width = "100%";
    "Mod+Shift+2".action.set-column-width = "50%";
    "Mod+Shift+3".action.set-column-width = "75%";
  };
}
