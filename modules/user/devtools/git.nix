# modules/user/devtools/git.nix
{ config, lib, pkgs, ... }:

let
  v = config.modules.private.values;
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = v.fullName;
      user.email = v.workEmail;

      credential.helper = "cache";
      safe.directory = "${config.home.homeDirectory}/nix-config";
      # http.proxy = "http://localhost:3128";
      # https.proxy = "http://localhost:3128";

      # Use SSH instead of HTTPS globally
      # url."git@github.com:".insteadOf = "https://github.com/";
      http.postBuffer = 524288000;
      http.version = "HTTP/1.1";
    } // lib.optionalAttrs (config.proxy.enable && config.proxy.http != null) {
      http.proxy = config.proxy.http;
    } // lib.optionalAttrs (config.proxy.enable && config.proxy.https != null) {
      https.proxy = config.proxy.https;
    };

    # Enable Git LFS if needed
    # lfs.enable = true;
  };

  home.packages = with pkgs; [
    git-credential-manager
  ];

  home.sessionVariables = {
    # GCM_CREDENTIAL_STORE = "generic";
  };
}
