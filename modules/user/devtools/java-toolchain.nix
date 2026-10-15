# modules/user/devtools/java-toolchain.nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.devtools.java;
  jdkPackages = import ../../shared/lib/jdk-packages.nix { inherit pkgs; };

  selectedJdk =
    jdkPackages.${cfg.defaultVersion} or (throw "Unknown Java version: ${cfg.defaultVersion}");

  # nixpkgs OpenJDK uses a wrapper; the real JDK is at lib/openjdk.
  # Temurin is not wrapped. We detect by pname since that's reliable here.
  javaHome =
    if lib.hasPrefix "temurin" (selectedJdk.pname or "") then
      "${selectedJdk}"
    else
      "${selectedJdk}/lib/openjdk";
in
{
  options.devtools.java = {
    enable = lib.mkEnableOption "Java development toolchain";

    defaultVersion = lib.mkOption {
      type = lib.types.enum [
        "8"
        "11"
        "17"
        "21"
      ];
      default = "17";
    };

    installVersions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "8"
          "11"
          "17"
          "21"
        ]
      );
      default = [ cfg.defaultVersion ];
    };

    # Export the resolved package so other modules don't recompute.
    selectedJdk = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "Resolved JDK package for the default version";
    };
  };

  config = lib.mkIf cfg.enable {
    devtools.java.selectedJdk = selectedJdk;
    home.packages = [ selectedJdk ];

    # Unwrapped path: tools that introspect JDK internals (Metals, IDEs) need this.
    # bin/java is already in PATH via home.packages.
    home.sessionVariables.JAVA_HOME = javaHome;

    home.file = lib.listToAttrs (
      lib.concatMap (v: [
        {
          name = "SDKs/Java/${v}";
          value.source = "${jdkPackages.${v}}";
        }
        {
          name = ".jdks/openjdk-${v}";
          value.source = "${jdkPackages.${v}}";
        }
      ]) cfg.installVersions
    );
  };
}
