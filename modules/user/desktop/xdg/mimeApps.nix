# modules/user/desktop/xdg/mimeApps.nix

let
  # TODO: refactor this modules to have app selection
  # as host-specific data, making this module generic and reusable accross hosts
  browser = "helium.desktop";
  file-manager = "org.system76.CosmicFiles.desktop";
  image-viewer = "org.kde.gwenview.desktop";
  video-player = "vlc.desktop";
  music-player = "org.system76.CosmicPlayer.desktop";
  code-editor = "zeditor.desktop";
  text-editor = "org.system76.CosmicEdit.desktop";
  document-viewer = "org.kde.okular.desktop";
  file-archiver = "org.kde.ark.desktop";
  torrent-client = "gopeed.desktop";
  download-manager = "gopeed.desktop";
  office-suite = "onlyoffice-desktopeditors.desktop";

in
{
  enable = true;
  defaultApplications = {
    "inode/directory" = file-manager;
    "x-scheme-handler/file" = [ file-manager ];
    "x-scheme-handler/about" = [ file-manager ];

    "application/pdf" = office-suite;
    "application/cbz" = document-viewer;
    "application/x-bzip2" = file-archiver;
    "application/x-gzip" = file-archiver;
    "application/x-tar" = file-archiver;
    "application/zip" = file-archiver;
    "application/json" = text-editor;
    "application/txt" = text-editor;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = office-suite;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = office-suite;
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = office-suite;
    "application/x-zerosize" = text-editor;

    "audio/mpeg" = music-player;
    "audio/flac" = music-player;
    "audio/vnd.wave" = music-player;

    "image/gif" = image-viewer;
    "image/jpeg" = image-viewer;
    "image/png" = image-viewer;
    "image/svg" = image-viewer;
    "image/tiff" = image-viewer;
    "image/webp" = image-viewer;

    "text/html" = browser;
    "text/xml" = text-editor;
    "text/markdown" = text-editor;
    "text/plain" = text-editor;

    "video/mpeg" = video-player;
    "video/webm" = video-player;
    "video/x-matroska" = video-player;
    "video/mp4" = video-player;

    "x-scheme-handler/http" = browser;
    "x-scheme-handler/https" = browser;
    # "x-scheme-handler/mailto" = "mailto-gmail.desktop";

    "x-scheme-handler/magnet" = torrent-client;
    "application/x-bittorrent" = torrent-client;
  };
}
