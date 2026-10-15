# modules/system/desktop/plasma.nix
{
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;
}
