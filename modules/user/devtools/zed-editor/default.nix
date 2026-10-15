# modules/user/devtools/zed-editor/default.nix
{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  theme = builtins.fromJSON (builtins.readFile ./transparent-tokyo.json);

  jdk =
    config.devtools.java.selectedJdk
      or (throw "Zed Metals config requires java-toolchain.nix to be enabled");

  javaHome = if lib.hasPrefix "temurin" (jdk.pname or "") then "${jdk}" else "${jdk}/lib/openjdk";

  # JDTLS (Zed "Java" extension >= 6.x) requires Java 21+ to *launch* the server.
  # The project default JDK stays at devtools.java.defaultVersion; this is only
  # the JVM used to run the language server itself.
  jdkPackages = import ../../../shared/lib/jdk-packages.nix { inherit pkgs; };
  jdk21Home = "${jdkPackages."21"}/lib/openjdk";
in
{
  imports = [ ../java-toolchain.nix ];

  home.packages = with pkgs; [
    marksman
    nixfmt
    metals
    nil
    gopls
    delve
    nodejs
    live-server
    docker-language-server
  ];

  programs.zed-editor = {
    enable = true;

    userTasks = [
      {
        label = "Start Live Server";
        command = "live-server";
        args = [
          "--host"
          "127.0.0.1"
          "--port"
          "8787"
          "--index"
          "."
        ];
        description = "Launches the local Rust live-server binary";
        use_new_terminal = true;
        allow_concurrent_runs = false;
      }
    ];

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "ctrl-shift-s" = [
            "task::Spawn"
            { task_name = "Start Live Server"; }
          ];
        };
      }
    ];

    userSettings = {
      theme = "One Dark";
      vim_mode = false;
      base_keymap = "VSCode";
      show_whitespaces = "none";
      ui_font_size = 14;
      buffer_font_size = 13;
      auto_update = false;
      features.inline_completion.enabled = false;
      load_direnv = "shell_hook";

      default_model = {
        provider = "zed.dev";
        model = "claude-3-5-sonnet-latest";
      };

      lsp = {
        "nil".settings = {
          formatting.command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
          diagnostics.ignored = [ "unused_binding" ];
          nix.flake.autoArchive = false;
        };

        "metals" = {
          binary.path = "${config.home.homeDirectory}/.local/bin/metals-wrapper";
          command = [ "${config.home.homeDirectory}/.local/bin/metals-wrapper" ];
          initialization_options = {
            javaHome = javaHome;
            isHttpEnabled = true;
            defaultBspToBuildTool = true;
            # Do NOT set bloopVersion here - presence triggers Bloop startup.
          };

          settings = {
            javaHome = javaHome;

            # BSP entry points isolate sbt/scala-cli child processes from
            # Metals' private COURSIER_CACHE (see metals-wrapper.nix).
            sbtScript = "${config.home.homeDirectory}/.local/bin/sbt-bsp";
            scalaCliLauncher = "${config.home.homeDirectory}/.local/bin/scala-cli-bsp";

            autoImportBuilds = "all";
            defaultBspToBuildTool = true;
            enableSemanticHighlighting = true;
          };
        };

        "gopls".binary.path = "${pkgs.gopls}/bin/gopls";

        "marksman".binary.path = "${pkgs.marksman}/bin/marksman";

        "jdtls".settings.java_home = jdk21Home;

        "docker-language-server".binary = {
          path = "${pkgs.docker-language-server}/bin/docker-language-server";
          arguments = [
            "start"
            "--stdio"
          ];
        };
      };

      languages = {
        "Nix" = {
          language_servers = [
            "nil"
            "!nixd"
          ];
        };
        "Go" = {
          language_servers = [ "gopls" ];
          formatter.external = {
            command = "gofmt";
            arguments = [ "-w" ];
          };
        };
        "Scala" = {
          tab_size = 2;
          hard_tabs = false;
        };
        "Markdown".language_servers = [ "!rumdl" ];
      };
    };

    extensions = [
      "nix"
      "astro"
      "toml"
      "make"
      "dockerfile"
      "docker-compose"
      "html"
      "xml"
      "yaml"
      "fish"
      "scala"
      "hocon"
      "java"
      "!rumdl"
      "codebook"
      "cspell"
    ];
  };
}
