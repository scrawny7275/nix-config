# modules/system/networking/bluetooth.nix
{ pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true; # Enable the Bluetooth service
    powerOnBoot = false; # Optionally power on the Bluetooth adapter at boot

    settings = {
      General = {
        Experimental = true; # Enable experimental features like battery reporting
      };
    };
  };

  environment.systemPackages = with pkgs; [
    bluez-tools # Provides tools like bluetoothctl
    # blueman # Full-featured Bluetooth manager (GUI) - Optional, might be in home.packages
  ];
}
