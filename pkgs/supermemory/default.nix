# pkgs/supermemory/default.nix
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "supermemory-server";
  version = "0.0.8";

  src = fetchurl {
    url = "https://github.com/supermemoryai/supermemory/releases/download/server-v${finalAttrs.version}/supermemory-server-linux-x64";
    hash = "sha256-h/MkM9AXm+gLudihuvusZa9BKDJDQqJ+y4vRp3tVBvM=";
  };

  # ELF is dynamically linked against glibc only (libc/pthread/dl/m);
  # autoPatchelfHook rewrites the interpreter to the Nix glibc.
  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++.so.6 — required by onnxruntime native binding
  ];

  dontUnpack = true;

  # Bun single-file executables append the application bundle (~200MB)
  # AFTER the ELF section headers. The default strip phase truncates the
  # file at the last section, deleting the bundle and leaving a binary
  # that falls back to stock `bun` CLI behavior ("Script not found").
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/supermemory-server
    runHook postInstall
  '';

  meta = with lib; {
    description = "Self-hosted memory and context engine (Memory API for the AI era)";
    homepage = "https://github.com/supermemoryai/supermemory";
    changelog = "https://github.com/supermemoryai/supermemory/releases/tag/server-v${finalAttrs.version}";
    license = licenses.mit;
    mainProgram = "supermemory-server";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
