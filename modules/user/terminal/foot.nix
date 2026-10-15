# modules/user/terminal/foot.nix
# Fast, lightweight and minimalistic Wayland terminal emulator
{
  programs.foot = {
    enable = true;
    server.enable = false;
    settings = {
      main = {
        font = "monospace:size=10.5";
        # Asymmetric padding: more vertical breathing room on 16:9
        pad = "12x8"; # horizontal x vertical, not "10x10"
        dpi-aware = "yes";
      };
      colors-dark = {
        alpha = "0.85";
      };
    };
  };
}
