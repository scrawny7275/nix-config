# In your home.nix or flake
# Feature-rich command-line audio/video downloader
{ config, pkgs, ... }:

{
  programs.yt-dlp = {
    enable = true;
    settings = {
      no-update = true;
      format = "bestvideo[height<=1080][vcodec^=avc1]+bestaudio/best[height<=1080]";
      merge-output-format = "mkv";
      audio-format = "best";
      audio-quality = "0";
      embed-metadata = true;
      embed-thumbnail = true;
      write-subs = true;
      sub-langs = "en,es";
      embed-subs = true;
      sponsorblock-remove = "sponsor,intro,outro";
      concurrent-fragments = 4;
    };
    extraConfig = ''
      --output "${config.home.homeDirectory}/Downloads/%(title)s [%(id)s].%(ext)s"
    '';
  };
}
