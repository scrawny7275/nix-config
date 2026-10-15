# pkgs/tide-island/default.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  makeWrapper,
  qt6,
  quickshell,
  wireplumber,
  pipewire,
  dbus,
  libpulseaudio,
  systemd,
  upower,
  bluez,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tide-island";
  version = "1.0.28";

  src = fetchFromGitHub {
    owner = "enhaoswen";
    repo = "Tide-island";
    rev = finalAttrs.version;
    hash = "sha256-qAxJtKUmMvPVMQcLOkiWdrcKaXGi2ZQTp6zQvwW5UvQ=";
  };

  nativeBuildInputs = [
    cmake
    python3
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qt5compat
    qt6.qtsvg
    qt6.qtwayland
    qt6.qtconnectivity
    quickshell
    wireplumber
    pipewire
    dbus
    libpulseaudio
    systemd
    upower
    bluez
  ];

  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

  postInstall = ''
    chmod +x $out/bin/tide-island
    chmod +x $out/bin/tide-island-config-app
    chmod +x $out/share/tide-island/bin/lyricsmpris
    rm -f $out/lib/qt6/qml/TideIsland/tide-island-config-app_qml_module_dir_map.qrc

    substituteInPlace $out/bin/tide-island \
      --replace-fail '/usr/bin/quickshell' '${quickshell}/bin/quickshell'

    wrapQtApp $out/bin/tide-island \
      --prefix QML_IMPORT_PATH : ${placeholder "out"}/lib/qt6/qml \
      --prefix QML2_IMPORT_PATH : ${placeholder "out"}/lib/qt6/qml
  '';

  meta = with lib; {
    description = "A dynamic island for Hyprland and niri using Quickshell";
    homepage = "https://github.com/enhaoswen/Tide-island";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
  };
})
