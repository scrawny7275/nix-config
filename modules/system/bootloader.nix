# modules/system/bootloader.nix
{ pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.blacklistedKernelModules = [
    "af_alg"
    "algif_hash"
    "algif_skcipher"
    "algif_rng"
    "algif_aead"
  ];
  boot.kernelModules = [ "kvm-intel" "ntfs3" ];
  boot.kernelParams = [
    "drm.edid_firmware=edid/hdr.bin"
    "video=1920x1080@60"
    "i915.fastboot=1"
    "fbcon=font:ter-c32b"
    "vconsole.font_map=8859-2"
  ];
  boot.initrd.kernelModules = [ "i915" ];

  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";

}
