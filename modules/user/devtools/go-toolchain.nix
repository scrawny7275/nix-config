# modules/user/devtools/go-toolchain.nix
{ config, lib, pkgs, ... }:

{
  programs.go = {
    enable = true;

    # TODO: the env vars for the proxy and checksum are host-specific
    env = lib.optionalAttrs (config.proxy.enable && config.proxy.http != null) {
      # GOPROXY: Go module proxy (not HTTP proxy). A private mirror URL can be
      # supplied here per-host when needed.
      # GOPROXY = "<private-go-module-proxy>";
    };
  };

  home.sessionVariables = {
    # GOPROXY = "<private-go-module-proxy>";
    # GOSUMDB = "off";
  };

  home.packages = with pkgs; [
    gopls # Official language server for the Go language
    golangci-lint # Fast linters Runner for Go
    golangci-lint-langserver # Language server for golangci-lint
  ];

  # SSL_CERT_FILE is already set globally by the certificates module.
  # Go picks it up automatically. No additional cert config needed here.
}
