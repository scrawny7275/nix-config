{ pkgs }:

with pkgs.javaPackages.compiler;
{
  "8" = openjdk8;
  "11" = pkgs.temurin-bin-11;
  "17" = openjdk17;
  "21" = openjdk21;
}
