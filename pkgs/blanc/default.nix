{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "blanc";
  version = "1.39.0";

  src = fetchurl {
    url = "https://github.com/bnfy/blanc/releases/download/v${version}/Blanc-${version}.AppImage";
    hash = "sha256-SidaR5lL0LuNn6a/hEhUIRVjjSJ2znpjLrYj13Kr8qg=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # wrapType2 discards the .desktop file and icon bundled in the AppImage;
  # install them so the launcher (COSMIC app library / niri launcher) picks
  # the app up (simpmusic pattern).
  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/blanc.desktop $out/share/applications/blanc.desktop
    install -Dm644 ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/blanc.png $out/share/icons/hicolor/1024x1024/apps/blanc.png
    substituteInPlace $out/share/applications/blanc.desktop \
      --replace-fail "Exec=AppRun %U" "Exec=blanc %U"
  '';

  # Electron/Chromium runtime, proven set for the FHS env (simpmusic list).
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
    description = "Open-source desktop browser with a minimal Island interface, built-in ad and tracker blocking";
    homepage = "https://github.com/bnfy/blanc";
    changelog = "https://github.com/bnfy/blanc/releases/tag/v${version}";
    license = licenses.mit;
    mainProgram = "blanc";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
