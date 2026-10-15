# pkgs/cosmic-ext-applet-netspeed/default.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  crane,
  pkgs,
  libcosmicAppHook,
  just,
  nix-update-script,
}:

let
  src = fetchFromGitHub {
    owner = "khanra17";
    repo = "cosmic-ext-applet-netspeed";
    rev = "main";
    hash = "sha256-NOq9PHoy9OW7vwDEHh46vziBKLhvGfU/d1isqtMBULQ=";
  };

  craneLib = crane.mkLib pkgs;

in
craneLib.buildPackage {
  inherit src;

  pname = "cosmic-ext-applet-netspeed";
  version = "unstable-2026-06-03";

  cargoLock = "${src}/Cargo.lock";

  nativeBuildInputs = [
    libcosmicAppHook
    just
  ];

  # crane already installs the binary via cargo install
  # We just need to add the missing .desktop file that upstream doesn't provide yet
  postInstall = ''
        # Generate the .desktop file since upstream doesn't include it
        mkdir -p $out/share/applications
        cat > $out/share/applications/io.github.khanra17.cosmic-ext-applet-netspeed.desktop <<'EOF'
    [Desktop Entry]
    Name=Net Speed
    Comment=Network speed monitoring applet for COSMIC
    Type=Application
    Icon=io.github.khanra17.cosmic-ext-applet-netspeed
    Exec=cosmic-ext-applet-netspeed
    Terminal=false
    Categories=System;Monitor;Network;
    Keywords=network;speed;monitor;applet;
    X-CosmicApplet=true
    EOF

        # If upstream ever adds icons, install them too
        if [ -d res/icons ]; then
          mkdir -p $out/share/icons/hicolor
          cp -r res/icons/* $out/share/icons/hicolor/
        fi
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Network speed monitoring applet for COSMIC";
    homepage = "https://github.com/khanra17/cosmic-ext-applet-netspeed";
    license = lib.licenses.gpl3Only;
    mainProgram = "cosmic-ext-applet-netspeed";
    platforms = lib.platforms.linux;
  };
}
