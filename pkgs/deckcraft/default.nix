{
  lib,
  stdenv,
  fetchurl,
  alsa-lib,
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
  # runtimeDependencies is applied last. Same dep set as wordcraft/pdfcraft:
  # identical upstream stack (winit/wgpu/rfd, same CI family).
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
  pname = "deckcraft";
  version = "0.8.0";

  src = fetchurl {
    url = "https://github.com/storytold/deckcraft/releases/download/v${finalAttrs.version}/deckcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-InuMnN0sBreGaAf5lf5dLQZ1UjphII+bwmzydg/dy48=";
  };

  # Release tarball layout (ArtCraft convention): deckcraft-<ver>-linux-x86_64/
  # {bin/deckcraft, share/…}.
  sourceRoot = "deckcraft-${finalAttrs.version}-linux-x86_64";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # alsa-lib: deckcraft links libasound.so.2 (DT_NEEDED) for slide audio —
  # the only sibling that does.
  buildInputs = [
    alsa-lib
    libgcc
  ];

  # autoPatchelfHook: appends runtimeDeps' lib dirs to the binaries' rpath.
  runtimeDependencies = runtimeDeps;

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/deckcraft $out/bin/deckcraft
    install -Dm755 bin/deckcraft-cli $out/bin/deckcraft-cli
    cp -a share/. $out/share/

    # Native Wayland on every launch path (user decision 2026-10-20). DeckCraft
    # runs through XWayland whenever X is actually reachable (same frontend
    # logic as wordcraft; verified live: a bare launch produced a
    # satellite-owned window with the gapless 1280x720 "fullscreen" tile), and
    # its X11 window opens at full-monitor size. The wrapper forces the native
    # Wayland backend — sharper text under fractional scaling too. Cost: no
    # file drag-and-drop (winit's Wayland backend). Escape hatch: run
    # $out/bin/.deckcraft-wrapped directly.
    # NOTE: headless backend tests with a bogus DISPLAY mislead here — the
    # X preference only triggers when X is genuinely connectable.
    wrapProgram $out/bin/deckcraft --set DECKCRAFT_WAYLAND 1

    runHook postInstall
  '';

  meta = {
    description = "Presentations and slide shows (PowerPoint reimplementation)";
    homepage = "https://github.com/storytold/deckcraft";
    changelog = "https://github.com/storytold/deckcraft/releases/tag/v${finalAttrs.version}";
    # Code: MIT OR Apache-2.0; bundled fonts: OFL (see the tarball's OFL-*.txt).
    license =
      with lib.licenses;
      AND [
        (OR [
          mit
          asl20
        ])
        ofl
      ];
    mainProgram = "deckcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
