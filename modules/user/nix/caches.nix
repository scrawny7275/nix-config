# modules/home/nix/caches.nix
{ pkgs, ... }:

{
  nix.package = pkgs.nix;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://hyprland.cachix.org"
      "https://niri.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
    extra-substituters = [
      "https://ags.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ags.cachix.org-1:ROlMBlA4jSD+mL8J9kq6HhMSr2h+NbeqQy8wTg0+Z94="
    ];
  };
}
