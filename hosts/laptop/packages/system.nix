# packages/system.nix
{ pkgs, ... }:

{
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    # mtpfs # FUSE Filesystem providing access to MTP devices
    gvfs # Virtual Filesystem support library
    usbutils # Tools for working with USB devices, such as lsusb
    udiskie # Removable disk automounter for udisks
    # ntfs3g removed — using in-kernel ntfs3 driver (boot.kernelModules)
    libmtp # Implementation of Microsoft's Media Transfer Protocol
    bitwarden-desktop # Secure and free password manager for all of your devices
    libsecret # Library for storing and retrieving passwords and other secrets (bitwarden posible need it )

    nix
    git
    busybox
    systemd
    util-linux
    e2fsprogs
    kmod
    lvm2
    kbd
  ];
}
