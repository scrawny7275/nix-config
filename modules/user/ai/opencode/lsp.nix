# modules/user/ai/opencode/lsp.nix
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.opencode;
  allLanguages = {
    # Built-in (need packages in PATH)
    nix.package = pkgs.nixd;
    go.package = pkgs.gopls;
    python.package = pkgs.pyright;
    typescript.package = pkgs.typescript;
    rust.package = pkgs.rust-analyzer;

    # Built-in (auto-install, no package needed)
    astro = { };
    bash = { };
    yaml = { };
    eslint = { };

    # Custom (need command + extensions)
    fish = {
      command = [
        "${pkgs.fish-lsp}/bin/fish-lsp"
        "start"
      ];
      extensions = [ ".fish" ];
      package = pkgs.fish-lsp;
    };
    dockerfile = {
      command = [
        "${pkgs.dockerfile-language-server}/bin/docker-langserver"
        "--stdio"
      ];
      extensions = [ "Dockerfile" ];
      package = pkgs.dockerfile-language-server;
    };
    html = {
      command = [
        "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server"
        "--stdio"
      ];
      extensions = [
        ".html"
        ".htm"
      ];
      package = pkgs.vscode-langservers-extracted;
    };
    css = {
      command = [
        "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server"
        "--stdio"
      ];
      extensions = [
        ".css"
        ".scss"
        ".less"
      ];
      package = pkgs.vscode-langservers-extracted;
    };
    json = {
      command = [
        "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server"
        "--stdio"
      ];
      extensions = [
        ".json"
        ".jsonc"
      ];
      package = pkgs.vscode-langservers-extracted;
    };
    scala = {
      # Shared wrapper (see scala-toolchain/metals-wrapper.nix): corporate
      # truststore + seeded private coursier cache for the Scala 3 PC.
      command = [ "${config.home.homeDirectory}/.local/bin/metals-wrapper" ];
      extensions = [
        ".scala"
        ".sbt"
        ".sc"
      ];
      # Wire only — flip "scala" on in programs.opencode.lsp.languages
      # (modules/user/ai/opencode/default.nix) to activate.
    };
  };

  isEnabled = lang: builtins.elem lang cfg.lsp.languages;

  enabledPackages = lib.unique (
    lib.concatMap (
      lang: lib.optional (allLanguages.${lang} ? package) allLanguages.${lang}.package
    ) cfg.lsp.languages
  );

  lspConfig =
    lib.filterAttrs
      (
        name: def:
        let
          enabled = isEnabled name;
          hasCustom = def ? command || def ? extensions;
        in
        (!enabled) || (enabled && hasCustom)
      )
      (
        lib.mapAttrs (
          name: def:
          if isEnabled name then
            lib.filterAttrs (
              k: _: k == "command" || k == "extensions" || k == "env" || k == "initialization"
            ) def
          else
            { disabled = true; }
        ) allLanguages
      );
in
{
  options.programs.opencode.lsp = {
    enable = lib.mkEnableOption "OpenCode LSP integration";
    languages = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames allLanguages));
      default = [ ];
      description = "Languages to enable LSP servers for. Unlisted built-ins remain enabled by default; unlisted customs remain disabled.";
    };
  };

  config = lib.mkIf cfg.lsp.enable {
    programs.opencode.extraPackages = enabledPackages;
    programs.opencode.settings.lsp = lspConfig;
  };
}
