# /modules/user/app/yazi.nix
# Yazi terminal file manager — declarative via HM release-26.05 `programs.yazi`.
# Yazi 26.5 uses the new config schema: [mgr] (was [manager]) in yazi.toml/keymap.toml/theme.toml.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.app.yazi;
in
{
  options.modules.user.app.yazi = {
    enable = lib.mkEnableOption "Yazi file manager" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;

      # `y` wrapper (default on stateVersion 26.05): cd's the shell to yazi's
      # cwd on exit. Enabled for both shells configured in this repo.
      enableZshIntegration = true;
      enableFishIntegration = true;

      # Only on yazi's wrapper PATH, not the global profile.
      extraPackages = with pkgs; [
        ffmpeg # video thumbnails
        imagemagick # image resize for previews
        poppler-utils # pdf previews
        file # mime detection
        fd # filename search
        ripgrep # content search
        jq # json previews
        p7zip # archive previews
        ouch # ouch.yazi plugin (archive list & compress/extract)
      ];

      settings = {
        mgr = {
          show_hidden = false;
          sort_by = "natural";
          sort_dir_first = true;
          linemode = "size";
        };
        preview = {
          max_width = 1000;
          max_height = 1000;
        };
        # Let ouch.yazi render archive contents in the preview pane.
        plugin.prepend_previewers = [
          {
            mime = "application/{*zip,x-tar,x-bzip*,x-7z-compressed,x-rar*,xz,zstd}";
            run = "ouch";
          }
        ];
      };

      # Git status badges setup via :setup(); chmod/smart-enter/ouch are
      # invoked on demand through the keybindings below.
      plugins = {
        git = {
          package = pkgs.yaziPlugins.git;
          setup = true;
        };
        inherit (pkgs.yaziPlugins) chmod smart-enter ouch;
      };

      keymap.mgr.prepend_keymap = [
        # Enter: enter dir or open file (replaces open-only default)
        {
          on = "<Enter>";
          run = "plugin smart-enter";
          desc = "Enter the child directory, or open the file";
        }
        {
          on = [
            "c"
            "m"
          ];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = "C";
          run = "plugin ouch --args=zip";
          desc = "Compress selected files to a zip archive";
        }
      ];

      theme.mgr.border_style = {
        type = "rounded";
      };
    };
  };
}
