# modules/shared/pkgs/sbt-1_4_7.nix
{
  lib,
  fetchurl,
  jdk,
  makeWrapper,
  runCommand,
  extraJvmOptions ? [ ],
}:

let
  sbtSrc = fetchurl {
    url = "https://github.com/sbt/sbt/releases/download/v1.4.7/sbt-1.4.7.tgz";
    sha256 = "1zal5lxbips276v63sp4443nzbzkcv6h13d8nlb1mhm383z5k9y2";
  };
in
runCommand "sbt-1.4.7-jdk8"
  {
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    mkdir -p $out/bin $out/share/sbt
    tar xzf ${sbtSrc} -C $out/share/sbt --strip-components=1

    makeWrapper $out/share/sbt/bin/sbt $out/bin/sbt --set JAVA_HOME ${jdk}/lib/openjdk --prefix PATH : ${jdk}/bin --add-flags "${lib.concatStringsSep " " extraJvmOptions}"
  ''
