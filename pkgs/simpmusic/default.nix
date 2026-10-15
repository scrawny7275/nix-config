# pkgs/simpmusic/default.nix
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "simpmusic";
  version = "2.0.0";

  src = fetchurl {
    url = "https://github.com/maxrave-dev/SimpMusic/releases/download/v${version}/SimpMusic-x86_64.AppImage";
    hash = "sha256-mA/V8RkUE/nTA5AEs5Sk+5Ma6S0aAPeALEMBpYVgH0E=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # wrapType2 discards the .desktop file and icon bundled in the AppImage;
  # install them so the launcher (COSMIC app library) picks the app up.
  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/simpmusic.desktop $out/share/applications/simpmusic.desktop
    install -Dm644 ${appimageContents}/simpmusic.png $out/share/icons/hicolor/128x128/apps/simpmusic.png
    substituteInPlace $out/share/applications/simpmusic.desktop \
      --replace-fail "Exec=bin/simpmusic %u" "Exec=simpmusic %u"
  '';

  extraPkgs =
    pkgs: with pkgs; [
      alsa-lib
      libpulseaudio
      mesa
      gtk3
      glib
      nss
      nspr
      dbus
      libX11
      libXext
      libXdamage
      libXfixes
      libXcomposite
      libXrandr
      libxkbcommon
      pango
      cairo
      atk
      at-spi2-atk
      cups
      expat
      libdrm
      libxcb
      vulkan-loader
      wayland
      libsecret
    ];

  meta = with lib; {
    description = "FOSS YouTube Music client for Desktop (Compose Multiplatform)";
    homepage = "https://github.com/maxrave-dev/SimpMusic";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "simpmusic";
  };
}
