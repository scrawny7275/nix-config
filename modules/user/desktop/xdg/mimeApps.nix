# modules/user/desktop/xdg/mimeApps.nix
# Generic default-application mapping — role selection is host-overridable
# data via modules.user.desktop.xdg.roleApps (see default.nix for the
# claiming contract and the mimeTypeOverrides escape hatch).
# Document types owned by the ArtCraft app modules — pdf, the word-processing
# family, the presentation family — are deliberately absent here: those
# modules self-register via mkDefault (modules/user/app/{wordcraft,pdfcraft,
# deckcraft}.nix). Spreadsheets stay on the office-suite role: no craft
# sibling exists.
{ roleApps }:

{
  enable = true;
  defaultApplications = {
    "inode/directory" = roleApps.file-manager;
    "x-scheme-handler/file" = [ roleApps.file-manager ];
    "x-scheme-handler/about" = [ roleApps.file-manager ];

    "application/cbz" = roleApps.document-viewer;
    "application/x-bzip2" = roleApps.file-archiver;
    "application/x-gzip" = roleApps.file-archiver;
    "application/x-tar" = roleApps.file-archiver;
    "application/zip" = roleApps.file-archiver;
    "application/json" = roleApps.text-editor;
    "application/txt" = roleApps.text-editor;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = roleApps.office-suite;
    "application/x-zerosize" = roleApps.text-editor;

    "audio/mpeg" = roleApps.music-player;
    "audio/flac" = roleApps.music-player;
    "audio/vnd.wave" = roleApps.music-player;

    "image/gif" = roleApps.image-viewer;
    "image/jpeg" = roleApps.image-viewer;
    "image/png" = roleApps.image-viewer;
    "image/svg" = roleApps.image-viewer;
    "image/tiff" = roleApps.image-viewer;
    "image/webp" = roleApps.image-viewer;

    "text/html" = roleApps.browser;
    "text/xml" = roleApps.text-editor;
    "text/markdown" = roleApps.text-editor;
    "text/plain" = roleApps.text-editor;

    "video/mpeg" = roleApps.video-player;
    "video/webm" = roleApps.video-player;
    "video/x-matroska" = roleApps.video-player;
    "video/mp4" = roleApps.video-player;

    "x-scheme-handler/http" = roleApps.browser;
    "x-scheme-handler/https" = roleApps.browser;
    # "x-scheme-handler/mailto" = "mailto-gmail.desktop";

    "x-scheme-handler/magnet" = roleApps.torrent-client;
    "application/x-bittorrent" = roleApps.torrent-client;
  };
}
