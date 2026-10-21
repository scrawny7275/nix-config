# modules/user/desktop/xdg/mimeApps.nix
# Generic default-application mapping — role selection is host data via
# modules.user.desktop.xdg.defaultApps (see default.nix for per-role override
# and the extraDefaultApplications escape hatch).
# Document types owned by the ArtCraft app modules — pdf, the word-processing
# family, the presentation family — are deliberately absent here: those
# modules self-register via mkDefault (modules/user/app/{wordcraft,pdfcraft,
# deckcraft}.nix). Spreadsheets stay on the office-suite role: no craft
# sibling exists.
{ defaultApps }:

{
  enable = true;
  defaultApplications = {
    "inode/directory" = defaultApps.file-manager;
    "x-scheme-handler/file" = [ defaultApps.file-manager ];
    "x-scheme-handler/about" = [ defaultApps.file-manager ];

    "application/cbz" = defaultApps.document-viewer;
    "application/x-bzip2" = defaultApps.file-archiver;
    "application/x-gzip" = defaultApps.file-archiver;
    "application/x-tar" = defaultApps.file-archiver;
    "application/zip" = defaultApps.file-archiver;
    "application/json" = defaultApps.text-editor;
    "application/txt" = defaultApps.text-editor;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = defaultApps.office-suite;
    "application/x-zerosize" = defaultApps.text-editor;

    "audio/mpeg" = defaultApps.music-player;
    "audio/flac" = defaultApps.music-player;
    "audio/vnd.wave" = defaultApps.music-player;

    "image/gif" = defaultApps.image-viewer;
    "image/jpeg" = defaultApps.image-viewer;
    "image/png" = defaultApps.image-viewer;
    "image/svg" = defaultApps.image-viewer;
    "image/tiff" = defaultApps.image-viewer;
    "image/webp" = defaultApps.image-viewer;

    "text/html" = defaultApps.browser;
    "text/xml" = defaultApps.text-editor;
    "text/markdown" = defaultApps.text-editor;
    "text/plain" = defaultApps.text-editor;

    "video/mpeg" = defaultApps.video-player;
    "video/webm" = defaultApps.video-player;
    "video/x-matroska" = defaultApps.video-player;
    "video/mp4" = defaultApps.video-player;

    "x-scheme-handler/http" = defaultApps.browser;
    "x-scheme-handler/https" = defaultApps.browser;
    # "x-scheme-handler/mailto" = "mailto-gmail.desktop";

    "x-scheme-handler/magnet" = defaultApps.torrent-client;
    "application/x-bittorrent" = defaultApps.torrent-client;
  };
}
