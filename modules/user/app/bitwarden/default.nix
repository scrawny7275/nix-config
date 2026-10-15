# modules/user/app/bitwarden/default.nix
#
# Bitwarden Desktop native messaging bridge for browsers.
#
# The Bitwarden desktop app writes manifests + proxy copies itself for the
# browsers it knows (brave, chrome, chromium, edge, firefox, vivaldi). This
# module covers everything else dynamically:
#
#   1. discover installed browsers via WebBrowser .desktop entries
#   2. classify them (mozilla-family via application.ini / chromium-family)
#   3. find their user data dirs by probing (profiles.ini / Local State)
#   4. check whether the Bitwarden extension is installed
#   5. write a com.8bit.bitwarden.json manifest (with the required `path`
#      key) + copy the desktop_proxy binary of the bitwarden-desktop the
#      system actually runs
#
# App-managed browsers are explicitly excluded so this never races or
# clobbers the app's own manifest generation.
#
# Implementation lives in ./bitwarden-native-messaging.sh so it can be run
# standalone for debugging (BW_NM_DRY_RUN=1 prints actions without writing).
{ config, lib, ... }:

let
  cfg = config.modules.user.app.bitwarden;
  script = "${./native-messaging.sh}";
in
{
  options.modules.user.app.bitwarden = {
    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable verbose logging during Bitwarden native messaging setup";
    };
  };

  config = {
    home.activation.bitwardenNativeMessaging = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.optionalString (!cfg.verbose) ''BW_NM_QUIET=1''} $DRY_RUN_CMD bash ${lib.escapeShellArg script}
    '';
  };
}
