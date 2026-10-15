# pkgs/escrcpy/default.nix
{
  lib,
  appimageTools,
  fetchurl,
  scrcpy,
  android-tools,
  gnirehtet,
}:

let
  pname = "escrcpy";
  version = "3.2.0";

  src = fetchurl {
    url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-x86_64.AppImage";
    hash = "sha256-VUn/N6BZnCunUTv/2uSh4JJETLAhjIsgKgdgAdJTCmY=";
  };

  # Replace the binaries bundled inside the AppImage with nixpkgs ones so
  # Escrcpy's resolution order (extraResources before PATH) picks up the
  # system scrcpy/adb/gnirehtet and keeps them in sync across upgrades.
  postExtract = ''
    runHook preExtractSwap

    linuxTools="$out/resources/extra/linux-x64/scrcpy"
    commonExtra="$out/resources/extra/common"

    # scrcpy 4.1 (same version Escrcpy 3.2.0 bundles)
    ln -sfn ${scrcpy}/bin/scrcpy "$linuxTools/scrcpy"
    # SCRCPY_SERVER_PATH points at this file — keep server next to the binary
    ln -sfn ${scrcpy}/share/scrcpy/scrcpy-server "$commonExtra/scrcpy/scrcpy-server"

    # adb / fastboot
    ln -sfn ${android-tools}/bin/adb "$linuxTools/adb"
    ln -sfn ${android-tools}/bin/fastboot "$linuxTools/fastboot"

    # gnirehtet (reverse tethering) — nixpkgs wraps the relay with its own APK
    ln -sfn ${gnirehtet}/bin/gnirehtet "$out/resources/extra/linux-x64/gnirehtet/gnirehtet"

    runHook postExtractSwap
  '';

  appimageContents = appimageTools.extract {
    inherit
      pname
      version
      src
      postExtract
      ;
  };
in
# wrapAppImage in stable-26.05 has no `contents` parameter; it wraps `src`
# directly. Pass the patched extraction as `src` (same trick wrapType2 uses).
appimageTools.wrapAppImage {
  inherit
    pname
    version
    ;

  src = appimageContents;

  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/escrcpy.desktop $out/share/applications/escrcpy.desktop
    substituteInPlace $out/share/applications/escrcpy.desktop \
      --replace-fail "Exec=AppRun --no-sandbox %U" "Exec=escrcpy %U"

    for icon in ${appimageContents}/usr/share/icons/hicolor/*/apps/escrcpy.png; do
      size="''${icon%/apps/*}"
      size="''${size##*/}"
      install -Dm644 "$icon" "$out/share/icons/hicolor/$size/apps/escrcpy.png"
    done
  '';

  extraPkgs =
    pkgs: with pkgs;
    [
      # Electron runtime dependencies
      nss
      nspr
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libdrm
      libsecret
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libxkbcommon
      libXrandr
      libxcb
      mesa
      pango
      wayland
      vulkan-loader

      # Escrcpy helpers: AppRun uses zenity/kdialog for prompts
      zenity
      # `which` module (node-which) shells out for binary resolution
      which
    ];

  meta = {
    description = "Graphical scrcpy front-end to display and control Android devices";
    homepage = "https://github.com/viarotel-org/escrcpy";
    changelog = "https://github.com/viarotel-org/escrcpy/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "escrcpy";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
