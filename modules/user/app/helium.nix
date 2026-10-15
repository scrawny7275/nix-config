# modules/user/app/helium.nix
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ inputs.helium-flake.nixosModules.default ];

  programs.helium = {
    enable = true;
    package = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;

    flags = [
      "--ozone-platform-hint=auto"
    ] ++ lib.optional (config.proxy.enable && config.proxy.http != null) "--proxy-server=${config.proxy.http}";

    policies = {
      "BrowserSignin" = 0;
      "PasswordManagerEnabled" = false;
      "SyncDisabled" = true;
      "SpellcheckEnabled" = true;
      "SpellcheckLanguage" = [ "en-US" ];
      "ExtensionInstallForcelist" = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
        "bhchdcejhohfmigjafbampogmaanbfkg" # User-Agent Switcher and Manager
        "eiadekoaikejlgdbkbdfeijglgfdalml" # WebRTC Leak Prevent
      ];
    };
  };
}
