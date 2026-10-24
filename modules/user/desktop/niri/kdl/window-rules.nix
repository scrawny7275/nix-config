# modules/user/desktop/niri/kdl/window-rules.nix
{ inputs }:

let
  inherit (inputs.niri.lib.kdl) plain leaf;

  niriDialogRounded = plain "window-rule" [
    (leaf "match" { app-id = "niri-confirmation"; })
    (leaf "geometry-corner-radius" 25)
    (leaf "clip-to-geometry" true)
  ];

  allWindowsRounded = plain "window-rule" [
    (leaf "geometry-corner-radius" 12)
    (leaf "clip-to-geometry" true)
    (leaf "tiled-state" true)
  ];

  allWindowsBlur = plain "window-rule" [
    (plain "background-effect" [
      (leaf "blur" true)
    ])
  ];

  firefoxPiPRule = plain "window-rule" [
    (leaf "match" {
      app-id = ''^org\.mozilla\.firefox$'';
      title = "^Picture-in-Picture$";
    })
    (leaf "open-floating" true)
  ];

  awwwLayerRule = plain "layer-rule" [
    (leaf "match" { namespace = "^awww-daemon$"; })
    (leaf "place-within-backdrop" true)
  ];

  protonVpnAllFloating = plain "window-rule" [
    (leaf "match" { app-id = "^protonvpn-app$"; })
    (leaf "open-floating" true)
  ];

  protonVpnMainTiled = plain "window-rule" [
    (leaf "match" {
      app-id = "^proton.vpn.app.gtk$";
      title = "^Proton VPN$";
    })
    (leaf "open-floating" false)
  ];

  # TODO: strategy to find a way of make dolphin main window excluded from the catch all rule
  # Window ID 120:
  #   Title: "1 — Dolphin"
  #   App ID: "org.kde.dolphin"
  #   Is floating: no
  #   PID: 470084
  #   Workspace ID: 7
  #   Layout:
  #     Tile size: 1264 x 704
  #     Scrolling position: column 1, tile 1
  #     Window size: 1264 x 704
  #     Window offset in tile: 0 x 0

  # Window ID 125:
  #   Title: "Copying (87% of 12.5 GiB) — Dolphin"
  #   App ID: "org.kde.dolphin"
  #   Is floating: no
  #   PID: 470084
  #   Workspace ID: 7
  #   Layout:
  #     Tile size: 415.33 x 216
  #     Scrolling position: column 2, tile 1
  #     Window size: 415 x 216
  #     Window offset in tile: 0 x 0
  dolphinAllFloating = plain "window-rule" [
    (leaf "match" { app-id = "^dolphin$"; })
    (leaf "open-floating" true)
  ];

  dolphinMainTiled = plain "window-rule" [
    (leaf "match" {
      app-id = "^dolphin$";
      title = "^.* - Dolphin$";
    })
    (leaf "open-floating" false)
  ];
in
[
  allWindowsRounded
  allWindowsBlur
  niriDialogRounded
  firefoxPiPRule
  awwwLayerRule
  protonVpnAllFloating
  protonVpnMainTiled
]
