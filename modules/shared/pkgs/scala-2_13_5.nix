# modules/shared/pkgs/scala-2_13_5.nix
{
  lib,
  fetchurl,
  scala,
  version ? "2.13.5",
}:

scala.overrideAttrs (oldAttrs: rec {
  inherit version;
  src = fetchurl {
    url = "https://github.com/scala/scala/releases/download/v${version}/scala-${version}.tgz";
    sha256 = "7SwhwR/HvDqF/VBHGsPBwSTn2B25pFiiV1FP3A3PBao=";
  };
})
