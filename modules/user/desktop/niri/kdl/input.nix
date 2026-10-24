# modules/user/desktop/niri/kdl/input.nix
{ inputs }:

let
  inherit (inputs.niri.lib.kdl)
    plain
    flag
    leaf
    ;

  config = plain "input" [
    (leaf "focus-follows-mouse" { max-scroll-amount = "0%"; })

    (plain "keyboard" [
      (plain "xkb" [
        (leaf "layout" "latam")
        # (leaf "layout" "us")
      ])
      # (leaf "repeat-delay" 600)
      # (leaf "repeat-rate" 25)
      (flag "numlock") # Enable numlock on startup
      # (leaf "track-layout" "global") # or "window"
    ])

    (plain "touchpad" [
      (flag "tap") # Enable tap-to-click
      (flag "dwt") # Disable while typing
      # (flag "dwtp") # Disable while trackpointing
      # (flag "natural-scroll") # Enable natural scrolling
      # (leaf "accel-speed" 0.2) # Adjust acceleration speed
      # (leaf "accel-profile" "flat") # or "adaptive"
      # (leaf "scroll-method" "two-finger") # or "edge", "on-button-down"
      # (flag "disabled-on-external-mouse")
    ])

    (plain "mouse" [
      # (flag "off") # Disable mouse input processing
      # (flag "natural-scroll")
      # (leaf "accel-speed" 0.2)
      # (leaf "accel-profile" "flat")
      # (leaf "scroll-method" "no-scroll") # or "on-button-down"
    ])

    (plain "trackpoint" [
      # (flag "off") # Disable trackpoint input processing
      # (flag "natural-scroll")
      # (leaf "accel-speed" 0.2)
      # (leaf "accel-profile" "flat")
      # (leaf "scroll-method" "on-button-down")
      # (leaf "scroll-button" 273) # Specify scroll button
      # (flag "scroll-button-lock")
      # (flag "middle-emulation")
    ])

    # (plain "tablet" [
    #   (leaf "map-to-output" "eDP-1") # Map tablet to specific output
    # ])

    # (plain "touch" [
    #   (leaf "map-to-output" "eDP-1") # Map touch input to specific output
    # ])

    # (flag "disable-power-key-handling") # Disable Niri's power key handling
  ];

in
[ config ]
