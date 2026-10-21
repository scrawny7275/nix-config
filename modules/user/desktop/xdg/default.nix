# modules/user/desktop/xdg/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  portal = import ./portal.nix { inherit pkgs; };
  mimeApps = import ./mimeApps.nix {
    defaultApps = config.modules.user.desktop.xdg.defaultApps;
  };

  cfg = config.modules.user.desktop.xdg;
in
{
  options.modules.user.desktop.xdg = {
    defaultApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Role → desktop ID for default applications. The module fills every
        role below with mkDefault, so hosts override any single role with a
        plain assignment; unset roles keep the defaults. Desktop IDs must be
        real files (the old org.system76.*/zeditor IDs here were dangling).
      '';
    };

    extraDefaultApplications = lib.mkOption {
      type =
        lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = { };
      description = ''
        Host-level per-MIME-type defaults merged at plain priority — beats
        the app modules' mkDefault self-registrations. Use to re-assert any
        type (e.g. "application/pdf" = "onlyoffice-desktopeditors.desktop")
        without touching the generic role mapping.
      '';
    };
  };

  config = {
    # Role fallbacks at mkDefault: a host assigning one role plainly keeps
    # the rest; a missing assignment would break the generic mapping, so
    # every role is always present.
    modules.user.desktop.xdg.defaultApps = lib.mapAttrs (_: lib.mkDefault) {
      browser = "helium.desktop";
      file-manager = "com.system76.CosmicFiles.desktop";
      image-viewer = "org.kde.gwenview.desktop";
      video-player = "vlc.desktop";
      music-player = "com.system76.CosmicPlayer.desktop";
      text-editor = "com.system76.CosmicEdit.desktop";
      document-viewer = "org.kde.okular.desktop";
      file-archiver = "org.kde.ark.desktop";
      torrent-client = "gopeed.desktop";
      office-suite = "onlyoffice-desktopeditors.desktop";
    };

    xdg = {
      portal = portal;
      mime.enable = true;
      mimeApps = mimeApps // {
        defaultApplications = (mimeApps.defaultApplications or { }) // cfg.extraDefaultApplications;
      };
    };
  };
}
