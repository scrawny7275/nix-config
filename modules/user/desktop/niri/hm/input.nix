# modules/user/desktop/niri/hm/input.nix
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
