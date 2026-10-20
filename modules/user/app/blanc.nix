# modules/user/app/blanc.nix
# bnfy/blanc — Electron/Chromium browser, AppImage wrap (simpmusic pattern).
# Notes (verified against upstream docs, v1.26+):
# - Blanc REFUSES any launch that disables the Chromium sandbox — never add
#   --no-sandbox; the wrapType2 FHS env keeps the launcher's user-namespace
#   probe passing (user.max_user_namespaces > 0 on this host).
# - electron-updater self-updates cannot replace a /nix/store path: update
#   checks fail harmlessly after downloading; upgrades are version+hash bumps
#   in pkgs/blanc.
{ pkgs, ... }:

let
  blanc = pkgs.callPackage ../../../pkgs/blanc { };
in
{
  home.packages = [ blanc ];
}
