# modules/user/desktop/niri/hmkdl/gestures.nix
{ inputs }:

let
  inherit (inputs.niri.lib.kdl) plain flag;

  gestures = plain "gestures" [
    # Configure hot corners
    (plain "hot-corners" [ (flag "off") ])
  ];

in
# Return the list of gesture nodes
[ gestures ]
