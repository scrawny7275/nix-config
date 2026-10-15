# modules/system/nix/nix-ld.nix
{ pkgs, ... }:

{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    glibc
    libgcc
    openssl
    zlib
    icu
  ];
}
