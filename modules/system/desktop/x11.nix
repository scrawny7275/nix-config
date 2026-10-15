# modules/system/desktop/x11.nix
{
  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver = {
    enable = false;
    videoDrivers = [ "modesetting" ];
    displayManager.lightdm.enable = false;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "latam";
    variant = "";
  };
}
