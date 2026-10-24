# modules/user/desktop/niri/kdl/debug.nix
{ inputs }:

let
  inherit (inputs.niri.lib.kdl)
    plain
    ;

  myDebugSettings = plain "debug" [
    # (flag "dbus-interfaces-in-non-session-instances")
    # (flag "wait-for-frame-completion-before-queueing")
    # (flag "enable-overlay-planes")
    # (flag "disable-cursor-plane")
    # (leaf "render-drm-device" "/dev/dri/renderD129")
    # (flag "enable-color-transformations-capability")
    # (flag "emulate-zero-presentation-time")
  ];

in
[ myDebugSettings ]
