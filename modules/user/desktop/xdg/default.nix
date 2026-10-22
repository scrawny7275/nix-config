# modules/user/desktop/xdg/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  portal = import ./portal.nix { inherit pkgs; };

  cfg = config.modules.user.desktop.xdg;

  mimeApps = import ./mimeApps.nix {
    roleApps = cfg.roleApps;
  };
in
{
  options.modules.user.desktop.xdg = {
    # Role → chosen desktop ID for the generic MIME mapping. The word
    # "default" is deliberately absent from this option name — that
    # vocabulary belongs to xdg.mimeApps.defaultApplications, the HM MIME
    # map these roles feed (the old name, defaultApps, collided with it).
    #
    # Claiming contract: any module may claim a role by assigning
    # `lib.mkDefault "<id>.desktop"` — option defaults lose to any config
    # assignment, host plain assignments beat module mkDefaults, and two
    # mkDefault claims on one role fail the merge loudly with both values
    # named. The schema closure is config-side only: an option declared
    # under roleApps from outside this module merges, but nothing consumes
    # it — a role exists only when its option and its mapping line in
    # mimeApps.nix are added together, here.
    roleApps = {
      browser = lib.mkOption {
        type = lib.types.str;
        default = "helium.desktop";
        description = "Web browser — consumes text/html, x-scheme-handler/http, x-scheme-handler/https.";
      };
      file-manager = lib.mkOption {
        type = lib.types.str;
        default = "com.system76.CosmicFiles.desktop";
        description = "File manager — consumes inode/directory, x-scheme-handler/file, x-scheme-handler/about. System-level COSMIC app (not in home-manager).";
      };
      image-viewer = lib.mkOption {
        type = lib.types.str;
        default = "org.kde.gwenview.desktop";
        description = "Image viewer — consumes image/gif, image/jpeg, image/png, image/svg, image/tiff, image/webp.";
      };
      video-player = lib.mkOption {
        type = lib.types.str;
        default = "vlc.desktop";
        description = "Video player — consumes video/mpeg, video/webm, video/x-matroska, video/mp4.";
      };
      music-player = lib.mkOption {
        type = lib.types.str;
        default = "com.system76.CosmicPlayer.desktop";
        description = "Music player — consumes audio/mpeg, audio/flac, audio/vnd.wave. System-level COSMIC app (not in home-manager).";
      };
      text-editor = lib.mkOption {
        type = lib.types.str;
        default = "com.system76.CosmicEdit.desktop";
        description = "Text editor — consumes application/json, application/txt, application/x-zerosize, text/xml, text/markdown, text/plain. System-level COSMIC app (not in home-manager).";
      };
      document-viewer = lib.mkOption {
        type = lib.types.str;
        default = "org.kde.okular.desktop";
        description = "Document viewer — consumes application/cbz only; the pdf/word/presentation families are owned by the ArtCraft app modules (modules/user/app/{pdfcraft,wordcraft,deckcraft}.nix).";
      };
      file-archiver = lib.mkOption {
        type = lib.types.str;
        default = "org.kde.ark.desktop";
        description = "File archiver — consumes application/zip, application/x-gzip, application/x-tar, application/x-bzip2.";
      };
      torrent-client = lib.mkOption {
        type = lib.types.str;
        default = "gopeed.desktop";
        description = "Torrent client — consumes x-scheme-handler/magnet, application/x-bittorrent.";
      };
      office-suite = lib.mkOption {
        type = lib.types.str;
        default = "onlyoffice-desktopeditors.desktop";
        description = "Office suite — consumes the OOXML spreadsheet type only (xlsx); the word-processing, pdf and presentation families are owned by the ArtCraft app modules.";
      };
    };

    # Escape hatch: per-MIME-type overrides at plain priority.
    mimeTypeOverrides = lib.mkOption {
      type =
        lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = { };
      description = ''
        Host-level per-MIME-type defaults merged at plain priority —
        beats every mkDefault contribution (roleApps selections and the
        app modules' MIME self-registrations). Use to re-assert any type
        (e.g. "application/pdf" = "onlyoffice-desktopeditors.desktop")
        without touching the generic role mapping.
      '';
    };
  };

  config = {
    xdg = {
      portal = portal;
      mime.enable = true;
      mimeApps = mimeApps // {
        defaultApplications = (mimeApps.defaultApplications or { }) // cfg.mimeTypeOverrides;
      };
    };
  };
}
