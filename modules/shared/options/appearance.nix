# modules/shared/options/appearance.nix
{ lib, ... }:

{
  options.appearance = {
    colorScheme = lib.mkOption {
      type = lib.types.enum [
        "default"
        "prefer-light"
        "prefer-dark"
      ];
      default = "prefer-dark";
      description = ''
        Declared system appearance — the single source of truth feeding the
        dconf color-scheme (what the portal answers on
        org.freedesktop.appearance) and any app that must be seeded to follow
        it (deckcraft: it ships no portal detection, unlike its siblings).
      '';
    };
  };
}
