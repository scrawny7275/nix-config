{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libgcc,
  makeWrapper,
  dbus,
  libX11,
  libxcb,
  libxcursor,
  libXi,
  libXrandr,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

let
  # dlopen'ed at runtime by winit, wgpu and rfd (libdbus, for the file dialogs).
  # Not DT_NEEDED, so they are fed to autoPatchelfHook via runtimeDependencies —
  # a manual postFixup rpath gets stripped by patchelf's fixup hook, while
  # runtimeDependencies is applied last. Same dep set the nixpkgs wordcraft
  # expression declares for this binary family.
  runtimeDeps = [
    libxkbcommon
    libX11
    libxcb
    libxcursor
    libXi
    libXrandr
    wayland
    vulkan-loader
    dbus
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "wordcraft";
  version = "0.8.0";

  src = fetchurl {
    url = "https://github.com/storytold/wordcraft/releases/download/v${finalAttrs.version}/wordcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-Ds4Hzz2RuSPf2A+QMQ4EmDveZvAnnGtg3c6JWW3eDd8=";
  };

  # Release tarball layout (same as the AUR wordcraft-bin PKGBUILD expects):
  # wordcraft-<ver>-linux-x86_64/{bin/wordcraft, bin/wordcraft-cli, share/…}
  sourceRoot = "wordcraft-${finalAttrs.version}-linux-x86_64";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ libgcc ];

  # autoPatchelfHook: appends runtimeDeps' lib dirs to the binaries' rpath.
  runtimeDependencies = runtimeDeps;

  dontConfigure = true;
  dontBuild = true;
  # Mirror the AUR's !strip on the upstream prebuilt binary.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/wordcraft $out/bin/wordcraft
    install -Dm755 bin/wordcraft-cli $out/bin/wordcraft-cli
    cp -a share/. $out/share/

    # Native Wayland on every launch path (user decision 2026-10-19). Upstream
    # prefers XWayland when X is available, but WordCraft's X11 window opens at
    # full-monitor size, which niri renders edge-to-edge — a "true fullscreen"
    # look (verified live: the satellite-owned window got a gapless 1280x720
    # tile instead of the normal 1264x704). Native Wayland also renders sharper
    # text under fractional scaling. Cost: winit's Wayland backend cannot
    # receive file drag-and-drop. Escape hatch: run .wordcraft-wrapped directly.
    wrapProgram $out/bin/wordcraft --set WORDCRAFT_WAYLAND 1

    runHook postInstall
  '';

  meta = {
    description = "Word processor with DOCX, ODT and RTF support";
    homepage = "https://github.com/storytold/wordcraft";
    changelog = "https://github.com/storytold/wordcraft/releases/tag/v${finalAttrs.version}";
    # Code: MIT OR Apache-2.0; bundled fonts and hyphenation data: OFL, CC0,
    # public domain (upstream ATTRIBUTION.md). Mirrors the nixpkgs expression.
    license =
      with lib.licenses;
      AND [
        (OR [
          mit
          asl20
        ])
        ofl
        cc0
        publicDomain
      ];
    mainProgram = "wordcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
