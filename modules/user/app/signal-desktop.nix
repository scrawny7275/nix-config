# modules/user/app/signal-desktop.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.signal-desktop;
in
{
  options.desktop.signal-desktop = {
    enable = lib.mkEnableOption "Signal Desktop with KWallet password store";

    passwordStore = lib.mkOption {
      type = lib.types.enum [
        "kwallet6"
        "gnome-libsecret"
        "basic_text"
      ];
      default = "kwallet6";
      description = "Backend for Signal's OS encryption keyring";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.kdePackages.kwallet
      (pkgs.symlinkJoin {
        name = "signal-desktop-wrapped";
        paths = [ pkgs.signal-desktop ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/signal-desktop \
            --add-flags '--password-store=${cfg.passwordStore}'
        '';
      })
    ];
  };
}
