# modules/system/desktop/cosmic.nix
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # upkgs = inputs.unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  upkgs = import inputs.unstable { inherit (pkgs.stdenv.hostPlatform) system; };

in
{
  # Overlay all COSMIC packages to use unstable versions
  nixpkgs.overlays = [
    (final: prev: {
      inherit (upkgs)
        cosmic-comp
        cosmic-applets
        cosmic-app-library
        cosmic-bg
        cosmic-edit
        cosmic-files
        cosmic-greeter
        cosmic-icons
        cosmic-idle
        cosmic-launcher
        cosmic-notifications
        cosmic-osd
        cosmic-panel
        cosmic-player
        cosmic-randr
        cosmic-screenshot
        cosmic-session
        cosmic-settings
        cosmic-settings-daemon
        cosmic-store
        cosmic-term
        cosmic-workspaces-epoch
        xdg-desktop-portal-cosmic
        ;
    })
  ];

  services.desktopManager.cosmic.enable = true;
  services.desktopManager.cosmic.xwayland.enable = true;
  services.displayManager.cosmic-greeter.enable = false;
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-initial-setup
    cosmic-greeter
  ];
  services.desktopManager.cosmic.showExcludedPkgsWarning = false;
}
