# modules/user/desktop/niri/kdl/settings.nix
{ inputs }:

let
  inherit (inputs.niri.lib.kdl)
    node
    plain
    leaf
    flag
    ;

  output = node "output" "eDP-1" [
    (leaf "scale" 1.5)
  ];

  layout = plain "layout" [
    (plain "border" [ (flag "off") ])
    (leaf "gaps" 8)
    (plain "focus-ring" [
      (leaf "width" 1.5)
      # (leaf "active-color" "#7fc8ff")
      (leaf "active-color" "#505050")
      (leaf "inactive-color" "#505050")
    ])
    (plain "default-column-width" [
      (leaf "proportion" 1.0)
    ])
  ];

  startupCommands = [
    # (leaf "spawn-at-startup" "mako")
    # (leaf "spawn-at-startup" [
    #   "ags"
    #   "run"
    # ])

    (leaf "spawn-at-startup" [
      "sh"
      "-c"
      "while ! busctl --user status org.gnome.Mutter.ScreenCast >/dev/null 2>&1; do sleep 0.2; done; systemctl --user restart xdg-desktop-portal-gnome"
    ])
    # (leaf "spawn-at-startup" "cosmic-panel")
    # (leaf "spawn-at-startup" "cosmic-osd")
    # (leaf "spawn-at-startup" "cosmic-launcher")
    (leaf "spawn-at-startup" "tide-island")
  ];

  screenshotPath = leaf "screenshot-path" "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

  animations = plain "animations" [ ];

  environment = plain "environment" [
    (leaf "NIXOS_OZONE_WL" "1")
    (leaf "MOZ_ENABLE_WAYLAND" "1")
    (leaf "GTK_USE_PORTAL" "1")
    (leaf "QT_QPA_PLATFORM" "wayland")
    (leaf "QT_SCALE_FACTOR_ROUNDING_POLICY" "RoundPreferFloor")
    (leaf "OZONE_PLATFORM" "wayland")
  ];

  layerRules = [
    (plain "layer-rule" [
      (leaf "match" { namespace = "^awww-daemon$"; })
      (leaf "place-within-backdrop" true)
    ])
  ];

  blur = plain "blur" [
    (leaf "passes" 3)
    (leaf "offset" 3)
    (leaf "noise" 0.02)
    (leaf "saturation" 1.5)
  ];

  recentWindows = plain "recent-windows" [
    (plain "highlight" [
      (leaf "corner-radius" 12)
      (leaf "active-color" "#7fc8ff")
      (leaf "urgent-color" "#ff9999ff")
      (leaf "padding" 30)
    ])

    # Optional: tweak preview sizing
    # (plain "previews" [
    #   (leaf "max-height" 480)
    #   (leaf "max-scale" 0.5)
    # ])
  ];

  hotkeyOverlay = plain "hotkey-overlay" [
    (flag "skip-at-startup")
    (flag "hide-not-bound")
  ];

  cursor = plain "cursor" [
    (leaf "xcursor-theme" "Bibata-Modern-Classic")
    (leaf "xcursor-size" 24)
  ];

in
[
  (flag "prefer-no-csd")
  output
  layout
  screenshotPath
  hotkeyOverlay
  animations
  environment
  blur
  recentWindows
  cursor
]
++ startupCommands
++ layerRules
