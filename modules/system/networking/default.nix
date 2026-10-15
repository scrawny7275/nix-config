# modules/system/networking/default.nix
{
  imports = [ ];

  # services.resolved.enable = true;
  # Enable networking
  networking.networkmanager.enable = true;
  # networking.networkmanager.dns = "systemd-resolved";

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  networking.firewall.checkReversePath = "loose";
}
