# modules/user/desktop/swayidle/default.nix
# Resume hook for sunsetr (psi4j/sunsetr#39): sunsetr 0.12.x recomputes the
# correct period on resume but silently fails to re-apply gamma to the display;
# restarting the daemon is the verified fix. swayidle listens for logind's
# resume signal inside the user session and restarts sunsetr on every wake.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.user.desktop.swayidle;

  # swaywm/swayidle#211: rapid suspend/resume cycles desync sd-bus and leave
  # the after-resume listener permanently (and silently) stuck — the exact
  # failure class this hook exists to prevent. Fix merged upstream (PR #209,
  # 2026-08-27) but unreleased; pin the fix commit until nixpkgs ships a
  # release >= 1.9.1, then drop this override (plain pkgs.swayidle).
  swayidleFixed = pkgs.swayidle.overrideAttrs (old: {
    version = "1.9.0-unstable-2026-08-27";
    src = pkgs.fetchFromGitHub {
      owner = "swaywm";
      repo = "swayidle";
      rev = "a959e59c64b55dd17a974dda4c4b71dff520af3a";
      hash = "sha256-U874D7FsHtGndBwnxNIW0MKebJTrYzX9ix7Cn2X4N/0=";
    };
  });
in
{
  options.modules.user.desktop.swayidle = {
    enable = lib.mkEnableOption "swayidle logind listener (sunsetr post-resume restart hook)";
  };

  config = lib.mkIf cfg.enable {
    services.swayidle = {
      enable = true;
      package = swayidleFixed;
      # Bind to the same target as the sunsetr unit itself.
      systemdTargets = [ "graphical-session.target" ];
      events = {
        # Absolute store paths: the home-manager swayidle unit sets PATH to a
        # bash-only binpath (swayidle execs commands via sh -c).
        # sleep 2: compositor readiness race right after resume (observed in
        # psi4j/sunsetr#39 — an immediate restart silently fails).
        "after-resume" =
          "${pkgs.coreutils}/bin/sleep 2 && ${pkgs.systemd}/bin/systemctl --user try-restart sunsetr.service";
      };
    };

    systemd.user.services.swayidle = {
      # The HM unit carries ConditionEnvironment=WAYLAND_DISPLAY; satisfy it
      # the same way the sunsetr unit does (hardcoded niri socket).
      Service.Environment = [ "WAYLAND_DISPLAY=wayland-1" ];
    };
  };
}
