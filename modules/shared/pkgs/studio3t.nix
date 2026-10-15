# modules/shared/pkgs/studio3t.nix
{
  pkgs ? import <nixpkgs> { },
}:

let
  studio3t = pkgs.stdenv.mkDerivation rec {
    pname = "studio3t";
    version = "2025.1.0";

    src = pkgs.fetchurl {
      url = "https://download-ce.studio3t.com/studio-3t/linux/${version}/studio-3t-community-edition-linux-x64.tar.gz";
      sha256 = "0f2fqmk19pljma2jchmxwpiq1rygij8n031l38xi2vn278v049py";
    };

    nativeBuildInputs = with pkgs; [
      makeWrapper
      autoPatchelfHook
      unzip
    ];

    buildInputs = with pkgs; [
      # Core runtime libraries
      glib
      gtk3
      libxtst
      libxxf86vm
      alsa-lib
      freetype
      fontconfig
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libXrender
      xorg.libXcursor
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXrandr
      xorg.libxcb
      nss
      nspr
      dbus
      cups
      expat
      libdrm
      mesa
      libxkbcommon
      # Java/Electron apps often need these
      zlib
      libpng
      libjpeg
      libxml2
      libxslt
      sqlite
      at-spi2-core
      at-spi2-atk
      atk
      pango
      cairo
      gdk-pixbuf
      # For MongoDB shell integration
      openssl
      curl
    ];

    unpackPhase = ''
      runHook preUnpack
      # The tarball contains a .sh self-extracting archive
      tar -xzf $src
      # Extract the makeself archive
      sh studio-3t-linux-x64.sh --target studio3t-extracted --noexec
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/studio3t
      cp -r studio3t-extracted/* $out/lib/studio3t/

      # Find the actual launcher binary (usually in a nested bin/ or app/ dir)
      # Studio 3T is Java-based, look for the main jar or shell script
      if [ -f "$out/lib/studio3t/bin/studio3t" ]; then
        makeWrapper $out/lib/studio3t/bin/studio3t $out/bin/studio3t \
          --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
          --set JAVA_HOME ${pkgs.jdk17}/lib/openjdk
      elif [ -f "$out/lib/studio3t/studio3t.sh" ]; then
        makeWrapper $out/lib/studio3t/studio3t.sh $out/bin/studio3t \
          --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
          --set JAVA_HOME ${pkgs.jdk17}/lib/openjdk
      else
        # Fallback: find any executable script or binary
        find $out/lib/studio3t -type f -executable | head -n1 | read -r launcher
        makeWrapper "$launcher" $out/bin/studio3t \
          --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}"
      fi

      # Install .desktop entry if present
      if [ -f "$out/lib/studio3t/studio3t.desktop" ]; then
        mkdir -p $out/share/applications
        cp $out/lib/studio3t/studio3t.desktop $out/share/applications/
        substituteInPlace $out/share/applications/studio3t.desktop \
          --replace 'Exec=.*' "Exec=$out/bin/studio3t"
      fi

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Studio 3T Community Edition - Free MongoDB GUI";
      homepage = "https://studio3t.com/free/";
      license = licenses.unfree; # Community Edition has usage restrictions
      platforms = [ "x86_64-linux" ];
      maintainers = [ ];
    };
  };
in
studio3t
