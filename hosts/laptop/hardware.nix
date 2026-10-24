# hosts/laptop/hardware.nix
# Generic hardware skeleton (public). The real machine scan — disk UUIDs included —
# lives in the private input (~/nix-config-private/hardware.nix) and is
# selected instead of this file when the override is active (see system.nix).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "rtsx_pci_sdmmc"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
