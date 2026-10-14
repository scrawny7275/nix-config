# modules/user/desktop/niri/hminput.nix
{
  input = {
    focus-follows-mouse.enable = true;

    keyboard = {
      xkb.layout = "latam";
      numlock = true;
    };

    touchpad = {
      tap = true;
    };
  };
}
