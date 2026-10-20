{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libgcc,
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
  # runtimeDependencies is applied last. Same runtimeDeps set as wordcraft:
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
  pname = "pdfcraft";
  version = "0.9.0";

  src = fetchurl {
    url = "https://github.com/storytold/pdfcraft/releases/download/v${finalAttrs.version}/pdfcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-/199o2oQiTQOP9umlrKGzDF6yPBwXMjETBxJ2cpMVOA=";
  };

  # Release tarball layout (wordcraft convention): pdfcraft-<ver>-linux-x86_64/
  # {bin/pdfcraft, bin/pdfcraft-cli, share/…}. The CLI (and its opt-in MCP
  # server) ships inside the GUI tarball; the separate pdfcraft-cli tarball
  # exists for servers/CI that do not want the GUI download.
  sourceRoot = "pdfcraft-${finalAttrs.version}-linux-x86_64";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ libgcc ];

  # autoPatchelfHook: appends runtimeDeps' lib dirs to the binaries' rpath.
  runtimeDependencies = runtimeDeps;

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/pdfcraft $out/bin/pdfcraft
    install -Dm755 bin/pdfcraft-cli $out/bin/pdfcraft-cli
    cp -a share/. $out/share/

    runHook postInstall
  '';

  meta = {
    description = "PDF reader and editor written from scratch in pure Rust";
    homepage = "https://github.com/storytold/pdfcraft";
    changelog = "https://github.com/storytold/pdfcraft/releases/tag/v${finalAttrs.version}";
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
    mainProgram = "pdfcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
