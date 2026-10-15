# /modules/user/app/thunar.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.app.thunar;
  niriCfg = config.modules.user.desktop.niri;
in
{
  options.modules.user.app.thunar = {
    enable = lib.mkEnableOption "Thunar file manager" // {
      default = true;
    };
    niriWindowRules = lib.mkOption {
      type = lib.types.bool;
      # TODO: for all patterns like this, make if possible this default value correspond to nif niri is enable.
      default = true;
      description = "Enable niri window rules for Thunar";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.thunar ];

    modules.user.desktop.niri.extraWindowRules =
      lib.mkIf (cfg.niriWindowRules && (niriCfg.enable or false))
        [
          {
            matches = [ { app-id = "^thunar$"; } ];
            open-floating = true;
          }
          {
            matches = [
              {
                app-id = "^thunar$";
                title = "^.* - Thunar$";
              }
            ];
            open-floating = false;
          }
        ];
  };
}
