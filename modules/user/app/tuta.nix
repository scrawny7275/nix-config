# modules/user/app/tuta.nix
{
  inputs,
  pkgs,
  ...
}:

let
  # nixos-26.05 still ships tutanota-desktop 348.260506.0, which Tuta's
  # server has rejected since ~2026-09-24 with HTTP 474
  # (InvalidSoftwareVersionError): resumeSession/login fail and the client
  # shows "Offline login is currently unavailable". Take the client from the
  # unstable channel input instead (GPL-3.0, no unfree predicate needed).
  unstablePkgs = inputs.unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  nixpkgs.overlays = [
    (final: prev: {
      tutanota-desktop = unstablePkgs.tutanota-desktop;
    })
  ];

  # The client rewrites ~/.local/share/applications/tutanota-desktop.desktop
  # on every launch (mailto registration). That imperative regular file
  # shadows the nix-profile entry (XDG_DATA_HOME outranks XDG_DATA_DIRS) and
  # its store path rots on GC → silent launcher failures. Pin it as a store
  # symlink to the current package entry (force replaces the imperative copy
  # on every switch): the HM generation pins the target against GC, and the
  # client's version check sees a matching X-Tutanota-Version so it skips
  # its own rewrite.
  xdg.dataFile."applications/tutanota-desktop.desktop" = {
    source = "${pkgs.tutanota-desktop}/share/applications/tutanota-desktop.desktop";
    force = true;
  };
}
