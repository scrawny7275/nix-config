# modules/user/app/anytype.nix
# In-tree pinned Anytype desktop (0.57.3 upstream, AppImage wrap — gopeed.nix pattern).
# Replaces the channel-tracked nixpkgs build (0.56.1 on current stable).
# Binary name is `anytype` (the GUI reclaims it); the agent CLI client is `anytype-cli`
# (modules/user/ai/anytype.nix) — swap decided 2026-10-03 after the name inversion
# broke the user's launch habit (typing `anytype` produced the CLI usage text).
{ config, pkgs, ... }:

let
  version = "0.57.3";
  src = pkgs.fetchurl {
    url = "https://github.com/anyproto/anytype-ts/releases/download/v${version}/Anytype-${version}.AppImage";
    sha256 = "sha256-8ztoP6O5pZlE3XfNqbnQepDgkAQxCOi41/KFyzXVG3w=";
  };

  # Extracted contents of the same AppImage — supplies icon + any other assets.
  appimageContents = pkgs.appimageTools.extractType2 {
    pname = "anytype";
    inherit version src;
  };

  appimage = pkgs.appimageTools.wrapType2 {
    pname = "anytype";
    inherit version src;
    extraPkgs =
      pkgs: with pkgs; [
        libsecret
        gtk3
        glib
      ];
    # Anytype rewrites ~/.local/share/applications/anytype.desktop (plus an
    # xwayland twin) on every launch, embedding its sandbox-interior exe path
    # — unlaunchable outside the wrap, shadowing the managed entry (this is
    # the true origin of the Oct 2 strays). tmpfs-mask the applications dir
    # inside the sandbox: self-registration lands on ephemeral storage and
    # never reaches the real home.
    extraBwrapArgs = [ "--tmpfs" "${config.xdg.dataHome}/applications" ];
  };

  desktopEntry = pkgs.makeDesktopItem {
    name = "anytype";
    desktopName = "Anytype";
    comment = "P2P note-taking / personal knowledge base";
    exec = "${appimage}/bin/anytype %u";
    icon = "anytype";
    categories = [ "Office" ];
    mimeTypes = [ "x-scheme-handler/anytype" ];
    startupNotify = true;
    startupWMClass = "anytype";
  };
in
{
  home.packages = [ appimage desktopEntry ];

  # Launcher-visible in XDG_DATA_HOME (tuta.nix pattern): tide-island scans
  # there first; a managed symlink can't go stale, and desktop-entry-guard
  # skips symlinks by design.
  xdg.dataFile."applications/anytype.desktop".source = "${desktopEntry}/share/applications/anytype.desktop";

  # Icon extracted from the pinned AppImage (no external fetch, no drift).
  home.file.".local/share/icons/hicolor/512x512/apps/anytype.png".source = "${appimageContents}/anytype.png";

  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "x-scheme-handler/anytype" = "anytype.desktop";
    };
  };
}
