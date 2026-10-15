# modules/user/devtools/scala-toolchain.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.devtools.scala;
  certPolicy = import ../../../shared/lib/certificates-policy.nix { inherit config lib; };
  certs = config.security.certificates;

  # Private maven mirror coordinates come from the private input
  # (stub: none — public repos only). See modules/user/employer.nix.
  v = config.modules.private.values;
  employerOn = config.modules.private.enable && v.nexus != null;

  sslFlags = lib.optionalString certs.enable (
    lib.concatStringsSep " " [
      "-Djavax.net.ssl.trustStorePassword=${certPolicy.javaTrustStorePassword}"
      "-Djavax.net.ssl.trustStore=${config.xdg.configHome}/nix/cacerts"
    ]
  );

  # Short timeouts so unreachable private-mirror repos fail fast off-VPN
  # (3s connect, 5s read) instead of hanging for 30s+ each.
  networkTimeouts = "-Dsun.net.client.defaultConnectTimeout=3000 -Dsun.net.client.defaultReadTimeout=5000";

  sbtOpts = lib.concatStringsSep " " (
    lib.filter (x: x != "") [
      sslFlags
      networkTimeouts
      "-Dfile.encoding=UTF-8"
    ]
  );

in
{
  # Hard dependency: it sets JDK and JAVA_HOME.
  imports = [
    ../java-toolchain.nix
    ./metals-repair.nix
  ];

  options.devtools.scala = {
    enable = lib.mkEnableOption "Scala development toolchain";

    repoMode = lib.mkOption {
      type = lib.types.enum [
        "default-only"
        "employer-launcher"
        "employer-global"
      ];
      default = "default-only";
      description = "default-only: public maven repos; employer-*: private mirrors from the private input";
    };

    sbtPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sbt;
      description = "SBT package to use with the configured repo mode";
    };

    scalaPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.scala_3;
      description = "Scala package to install globally, or null for none";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages =
          lib.optional (cfg.scalaPackage != null) cfg.scalaPackage
          ++ (with pkgs; [
            scala-cli
            scalafmt
          ]);
      }

      # SBT credentials
      # NOTE: host and user are plain strings (not secrets), resolved from the
      # private private input; only the password comes from sops at runtime.
      {
        sops.secrets."sbt_nexus/password".mode = "0600";
      }

      # JVM-wide SSL and network config. NOT SBT-specific.
      {
        home.sessionVariables = {
          JAVA_TOOL_OPTIONS = "${sslFlags} ${networkTimeouts}"; # Metals, Bloop, Coursier all read this
          SBT_OPTS = sbtOpts;
        };
      }

      # Private Coursier mirrors — needed by Metals too, not just SBT.
      # Chain comes from the private input; Central is always in it as fallback.
      (lib.mkIf (cfg.repoMode != "default-only" && employerOn) {
        home.sessionVariables.COURSIER_REPOSITORIES = v.coursierRepositoriesToolchain;
      })

      # SBT program configuration
      {
        programs.sbt = {
          enable = true;
          package = cfg.sbtPackage.override { jre = config.devtools.java.selectedJdk; };
          credentials = lib.mkIf (cfg.repoMode != "default-only" && employerOn) [
            {
              realm = "Sonatype Nexus Repository Manager";
              host = v.nexus.primary;
              user = v.nexus.user;
              passwordCommand = "cat ${config.sops.secrets."sbt_nexus/password".path}";
            }
          ];
        };
      }

      (lib.mkIf (cfg.repoMode == "employer-launcher" && employerOn) {
        # Launcher-mode resolver list ships inside the private input.
        programs.sbt.repositories = v.sbtRepositories;
      })

      (lib.mkIf (cfg.repoMode == "employer-global" && employerOn) {
        # Global resolvers file ships inside the private input.
        home.file.".sbt/1.0/global.sbt".text = builtins.readFile (inputs.private + "/resolvers.sbt");
      })
    ]
  );
}
