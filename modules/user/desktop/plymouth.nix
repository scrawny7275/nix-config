# modules/user/desktop/plymouth.nix
{ pkgs, mac-style-plymouth, ... }:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "mac-style";
      themePackages = [ mac-style-plymouth.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };
    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "systemd.show_status=auto"
    ];
  };
}
