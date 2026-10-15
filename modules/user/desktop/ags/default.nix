# modules/user/desktop/ags/default.nix
{ inputs, pkgs, ... }:

{
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;
    configDir = ./.;
    extraPackages = with pkgs; [
      inputs.astal.packages.${pkgs.stdenv.hostPlatform.system}.battery
      fzf
    ];
  };

  # Astal CLI tools
  home.packages = [
    inputs.astal.packages.${pkgs.stdenv.hostPlatform.system}.notifd
  ];
}
