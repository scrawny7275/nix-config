# pkgs/yaru-icons/default.nix
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
}:

stdenvNoCC.mkDerivation rec {
  pname = "yaru-icons";
  version = "26.04.5.1ubuntu";

  src = fetchFromGitHub {
    owner = "ubuntu";
    repo = "yaru";
    tag = version;
    hash = "sha256-HnEp7Rn6wF5mXiQLDIb5iWTrr+13MCYCeVPwlnfC7Ds=";
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ python3 ];

  # Upstream ships fully prebuilt icon themes (all accent variants, light and
  # dark) under icons/Yaru*; the meson/sassc build only regenerates them.
  # -L dereferences symlinks: variants symlink into Yaru and src trees.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons
    cp -rL --remove-destination icons/Yaru* $out/share/icons/

    # index.theme is meson-generated upstream — regenerate it here so the
    # themes are usable without the full build.
    python=$(command -v python3)
    for theme in $out/share/icons/Yaru*; do
      name=$(basename "$theme")
      "$python" icons/src/generate-index-theme.py "$name" \
        --source-dir "$theme" \
        --output-dir "$theme"
    done

    runHook postInstall
  '';

  meta = {
    description = "Ubuntu Yaru icon theme suite (all accent variants, prebuilt)";
    homepage = "https://github.com/ubuntu/yaru";
    changelog = "https://github.com/ubuntu/yaru/releases/tag/${version}";
    license = [
      lib.licenses.cc-by-sa-40
      lib.licenses.gpl3
    ];
    platforms = lib.platforms.linux;
  };
}
