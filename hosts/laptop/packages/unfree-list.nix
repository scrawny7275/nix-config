# hosts/laptop/packages/unfree-list.nix
#
# Shared allow-list of unfree package names, consumed by:
#   - hosts/laptop/packages/unfree.nix (NixOS predicate)
#   - flake.nix homeConfigurations (standalone home-manager pkgs import)
# Keep this list as the single source of truth.
[
  "vscode"
  "unrar"
  "wpsoffice"
  "anytype"
  "anytype-heart"
  "ventoy"
  "idea-with-plugins"
  "idea"
  "postman"
  "datagrip"
  "dbvisualizer"
  "spotify"
  "appflowy"
  # escrcpy eval-time requirement (appimageTools asserts on the unfree
  # android platform-tools zip even though it never reaches the runtime
  # closure)
  "android-sdk-platform-tools"
  "platform-tools"
  "platform-tools_r37.0.0-linux.zip"
]
