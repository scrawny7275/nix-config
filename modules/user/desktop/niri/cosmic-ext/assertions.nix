# modules/user/desktop/niri/cosmic-ext/assertions.nix
{ cfg, config }:

{
  assertions = [
    {
      assertion = cfg.polkit -> !config.services.gnome-keyring.enable;
      message = ''
        programs.cosmic-ext-niri.polkit conflicts with services.gnome-keyring
        (which includes the GNOME polkit agent). Disable one or the other.
      '';
    }
  ];
}
