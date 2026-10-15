# modules/user/app/gopeed.nix
{ pkgs, ... }:

let
  gopeed-appimage = pkgs.appimageTools.wrapType2 rec {
    pname = "gopeed";
    version = "1.9.3";
    src = pkgs.fetchurl {
      url = "https://github.com/GopeedLab/gopeed/releases/download/v${version}/Gopeed-v${version}-linux-amd64.AppImage";
      sha256 = "0v4ldx6ldvxy0hj0hsqyjc0sqm831smi4m4m9g6kh3imsb2iwr6c";
    };
    extraPkgs =
      pkgs: with pkgs; [
        libsecret
        libayatana-appindicator
        libepoxy
        gtk3
        glib
        pango
        cairo
        gdk-pixbuf
        harfbuzz
        atk
        jsoncpp
        libdbusmenu
      ];
  };

  gopeed-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/GopeedLab/gopeed/v1.9.3/ui/flutter/assets/icon/icon_512.png";
    sha256 = "sha256-bzQut1YPJe2gZiI67rB0iR4zb0akGAf+pB35/cjfLtA=";
  };

  # Wrapper script that properly handles URLs passed as arguments
  gopeed-wrapper = pkgs.writeShellScriptBin "gopeed-launcher" ''
    #!/usr/bin/env bash
    # Gopeed sometimes fails when launched with xdg-open due to AppImage FUSE/URL handling
    # This wrapper ensures magnet links and torrent files are passed correctly

    export APPIMAGE_SILENT_INSTALL=1

    # If running under xdg-open, the URL might be passed as argument
    if [ $# -eq 0 ]; then
      exec ${gopeed-appimage}/bin/gopeed
    else
      exec ${gopeed-appimage}/bin/gopeed "$@"
    fi
  '';

in
{
  home.packages = [
    gopeed-appimage
    gopeed-wrapper
  ];

  xdg.desktopEntries.gopeed = {
    name = "Gopeed";
    genericName = "Download Manager";
    comment = "Modern download manager";
    # Use the wrapper instead of calling the AppImage directly
    exec = "${gopeed-wrapper}/bin/gopeed-launcher %U";
    icon = "gopeed";
    terminal = false;
    categories = [
      "Network"
      "FileTransfer"
    ];
    mimeType = [
      "application/x-bittorrent"
      "x-scheme-handler/magnet"
    ];
    # Ensure the desktop entry is associated with the correct StartupWMClass
    settings = {
      StartupWMClass = "gopeed";
      StartupNotify = "true";
    };
  };

  home.file.".local/share/icons/hicolor/512x512/apps/gopeed.png".source = gopeed-icon;

  # Ensure xdg-mime knows about the association (belt and suspenders)
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/x-bittorrent" = "gopeed.desktop";
      "x-scheme-handler/magnet" = "gopeed.desktop";
    };
  };
}
