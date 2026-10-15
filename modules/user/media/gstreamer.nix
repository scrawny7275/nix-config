# modules/user/media/gstreamer.nix
{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base # contains playbin
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav # ffmpeg codecs for most video formats
  ];

  home.sessionVariables = {
    GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPath "lib/gstreamer-1.0" [
      pkgs.gst_all_1.gstreamer.out
      pkgs.gst_all_1.gst-plugins-base
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.gst_all_1.gst-plugins-ugly
      pkgs.gst_all_1.gst-libav
    ];
  };
}
