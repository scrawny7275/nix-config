# pkgs/opencode — prebuilt CLI from the upstream release assets.
# Version mirrors the opencode flake input's CLI package (the source-built
# package this one replaces): 1.19.3+a1f604b → 1.19.3. The co-installed
# desktop stays same-release via the shared input pin, not via this string.
# Only the fetchurl hash below is manual (nix store prefetch-file on
# mismatch).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  installShellFiles,
  makeWrapper,
  ripgrep,
  wayland,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  upstreamCliVersion ? throw "pkgs/opencode: pass upstreamCliVersion = inputs.opencode.packages.<system>.opencode.version",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = lib.head (lib.splitString "+" upstreamCliVersion);

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${finalAttrs.version}/opencode-linux-x64.tar.gz";
    hash = "sha256-E6j7KXgwIHG4b51+ANqciJX5zYRpeDecO9xqUzNTbJs=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    installShellFiles
    makeWrapper
    writableTmpDirAsHomeHook
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];

  buildInputs = [ glibc ];

  # dlopen'ed by OpenTUI at runtime (clipboard images): lands in DT_RUNPATH
  # via autoPatchelf — not in a wrapper's LD_LIBRARY_PATH.
  runtimeDependencies = [ wayland ];

  # Flat tarball: a lone ./opencode member, no wrapping directory.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  # PROVEN on this pin (nixpkgs 26.05, patchelf 0.15.2, 2026-10-20): the
  # fixup-phase strip rewrites the ELF section table and orphans bun's
  # appended app payload (the binary degrades to bare bun, reporting the
  # runtime's version); ELF patching via autoPatchelfHook with strip
  # disabled is payload-safe. versionCheckHook turns any regression of
  # either fact into a hard build failure.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    tar -xOf $src opencode > $out/bin/opencode
    chmod 755 $out/bin/opencode

    # ripgrep on PATH, mirroring upstream nix/opencode.nix.
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    local bin=$out/bin/.opencode-wrapped
    # Build-time only: the ELF is still pristine here (autoPatchelf patches in
    # postFixup) and the sandbox has no /lib64 loader, so exec it through the
    # glibc loader to generate completions. Runtime is the standard patched
    # interpreter + DT_RUNPATH chain.
    installShellCompletion --cmd opencode \
      --bash <("${glibc}/lib/ld-linux-x86-64.so.2" "$bin" completion bash) \
      --zsh <("${glibc}/lib/ld-linux-x86-64.so.2" "$bin" completion zsh) \
      --fish <("${glibc}/lib/ld-linux-x86-64.so.2" "$bin" completion fish)
  '';

  doInstallCheck = true;
  versionCheckProgramArg = "--version";
  # --version startup wants a writable HOME (data dir) and would otherwise
  # fetch models.dev; keep both through versionCheckHook's env scrubbing.
  env.OPENCODE_DISABLE_MODELS_FETCH = true;
  versionCheckKeepEnvironment = [
    "HOME"
    "OPENCODE_DISABLE_MODELS_FETCH"
  ];

  meta = {
    description = "Open source coding agent (prebuilt upstream release binary)";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
