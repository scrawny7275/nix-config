# modules/user/desktop/swayosd/default.nix
let
  theme = import ../theme.nix; # adjust path as needed
in
{
  services.swayosd = {
    enable = true;
    topMargin = 0.9;
  };
  # Generate the CSS file with theme colors injected
  xdg.configFile."swayosd/style.css".text = theme.substitute ./style.css;
}
