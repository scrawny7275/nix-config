# modules/user/desktop/niri/hm/settings.nix
{
  prefer-no-csd = true;

  outputs."eDP-1" = {
    scale = 1.5;
  };

  layout = {
    border.enable = false;
    gaps = 8;
    focus-ring = {
      width = 1;
      active.color = "#7fc8ff";
      inactive.color = "#505050";
    };
    default-column-width.proportion = 1.0;
  };

  screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

  hotkey-overlay = {
    skip-at-startup = true;
    hide-not-bound = true;
  };

  animations = {
    # Empty section - defaults
  };

  environment = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_USE_PORTAL = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
    OZONE_PLATFORM = "wayland";
  };

  spawn-at-startup = [
    { argv = [ "mako" ]; }
  ];

  layer-rules = [
    {
      matches = [ { namespace = "^awww-daemon$"; } ];
      place-within-backdrop = true;
    }
  ];

  # blur = {
  #   passes = 3;
  #   offset = 3.0;
  #   noise = 0.02;
  #   saturation = 1.5;
  # };
}
