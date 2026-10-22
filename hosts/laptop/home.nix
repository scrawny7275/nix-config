# hosts/laptop/home.nix
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Personal + employer values from the private input (stub by default).
  # See modules/user/private.nix.
  v = config.modules.private.values;
in
{
  home.username = v.userName;
  home.homeDirectory = lib.mkForce "/home/${v.userName}";
  home.stateVersion = "26.05";

  # home.sessionVariables only writes to ~/.profile (login shells).
  # systemd.user.sessionVariables writes to environment.d, which desktop
  # apps (Zed, IntelliJ, etc.) actually inherit when launched from compositor.
  # home.sessionVariables only writes to ~/.profile (login shells).
  # systemd.user.sessionVariables writes to environment.d, which desktop
  # apps (Zed, IntelliJ, etc.) actually inherit when launched from compositor.
  # COURSIER_REPOSITORIES: central FIRST (publicly reachable, where the
  # pinned PC set is seeded), private mirrors after (on-VPN).
  # Coursier walks in order; mirror-first caused NXDOMAIN timeouts to block
  # before central was ever tried. Chain comes from the private input.
  systemd.user.sessionVariables = {
    COURSIER_REPOSITORIES = v.coursierRepositories;
    JAVA_HOME = config.home.sessionVariables.JAVA_HOME or "";
    JAVA_TOOL_OPTIONS = config.home.sessionVariables.JAVA_TOOL_OPTIONS or "";
    SBT_OPTS = config.home.sessionVariables.SBT_OPTS or "";
  };

  imports = [
    ../../modules/user/nix/nix-index.nix
    ../../modules/user/nix/caches.nix
    ../../modules/user/nix/gc-roots.nix
    ../../modules/user/nix/registry.nix
    ../../modules/user/nix/nix-your-shell.nix

    inputs.sops-nix.homeManagerModules.sops
    ../../modules/user/private.nix
    ./packages/user.nix
    ../../modules/user/fonts.nix

    # Security foundation (must be imported before consumers)
    ../../modules/user/security/certificates

    ../../modules/user/media/gstreamer.nix

    # Development toolchains (consumers of certificates)
    ../../modules/user/devtools/java-toolchain.nix
    ../../modules/user/devtools/scala-toolchain
    ../../modules/user/devtools/scala-toolchain/metals-wrapper.nix
    ../../modules/user/devtools/go-toolchain.nix
    ../../modules/user/devtools/zed-editor
    ../../modules/user/devtools/idea.nix
    ../../modules/user/devtools/podman.nix
    ../../modules/user/devtools/git.nix
    ../../modules/user/devtools/direnv.nix

    ../../modules/user/ai/opencode
    ../../modules/user/ai/caveman.nix
    ../../modules/user/ai/anytype.nix

    ./ssh
    ../../modules/user/security/ssh.nix

    ../../modules/user/shell/zsh
    ../../modules/user/shell/fish
    ../../modules/user/terminal/kitty.nix
    ../../modules/user/terminal/alacritty.nix
    ../../modules/user/terminal/foot.nix
    ../../modules/user/terminal/rio.nix
    ../../modules/user/terminal/ghostty.nix

    ../../modules/user/desktop/niri
    ../../modules/user/desktop/cosmic
    ../../modules/user/desktop/plasma-manager.nix
    ../../modules/user/desktop/ags
    ../../modules/user/desktop/gtk.nix
    ../../modules/user/desktop/qt.nix
    ../../modules/user/app/yaru-icons.nix
    ../../modules/user/desktop/xsettings.nix
    ../../modules/user/desktop/dconf.nix
    ../../modules/user/desktop/x11.nix

    # TODO: Consider if this is properly imprted here or should be part of the ./packages axis
    #   Consider if it should be a better classifction rather than use generic app, e.g.
    #   alpaca is an service/app considered part of the networking
    # Desktop applications
    ../../modules/user/app/wpaperd.nix
    ../../modules/user/app/signal-desktop.nix
    ../../modules/user/app/brave
    ../../modules/user/app/bitwarden
    ../../modules/user/app/db-visualizer.nix
    ../../modules/user/app/yt-dlp.nix
    ../../modules/user/app/udiskie.nix
    ../../modules/user/app/simpmusic.nix
    ../../modules/user/app/sonora.nix
    ../../modules/user/app/escrcpy.nix
    ../../modules/user/app/desktop-entry-guard.nix
    ../../modules/user/app/yazi.nix
    ../../modules/user/app/tuta.nix
    ../../modules/user/app/anytype.nix # pinned 0.57.3 AppImage (replaces channel anytype)
    ../../modules/user/app/wordcraft.nix # pinned 0.8.0 release tarball (binary)
    ../../modules/user/app/pdfcraft.nix # pinned 0.9.0 release tarball (binary; ArtCraft)
    ../../modules/user/app/deckcraft.nix # pinned 0.8.0 release tarball (binary; ArtCraft)
    ../../modules/user/app/blanc.nix # pinned 1.39.0 AppImage (Electron browser)

    ../../modules/user/networking/alpaca.nix
    ./proxy-options.nix

  ];

  # TODO: Create an assert function or logs in home build that warns about not-imported modules
  security.certificates.policyFile = ./policy.nix;

  devtools.java = {
    enable = true;
    defaultVersion = "17";
    installVersions = [
      "8"
      "11"
      "17"
      "21"
    ];
  };

  devtools.scala = {
    enable = true;
    repoMode = v.sbtRepoMode;
    scalaPackage = pkgs.scala_3;
    sbtPackage = pkgs.sbt;
    repair = {
      enable = true;
      projects = [ "~/IdeaProjects/doc-manager" ];
      autoDiscover = true;
      schedule = "weekly";
      autoRepair = true;
      autoRepairAfter = 20;
      autoRepairCooldown = 60;
      checkInterval = "10min";
    };
  };

  modules.user.desktop.niri.useKdlConfig = true;

  modules.user.app.desktopEntryGuard.enable = true;
  modules.user.desktop.xdg.mimeAppsScan.enable = true; # existence gate for MIME defaults (registry = fitness gate)

  # The laptop's explicit desktop-app policy. Plain assignments beat the
  # module defaults and are validated against the roleCandidates registry
  # at eval — a typo'd or unregistered ID fails the build with the
  # registered alternatives named. The module's defaults remain as the
  # portable fallback profile for hosts that declare nothing (and for any
  # role left unset here).
  modules.user.desktop.xdg.roleApps = {
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

  # Caveman: token-sink analyzer for agent sessions (`caveman learn`, read-only).
  # Go binaries + CLI packaged in modules/user/ai/caveman.nix (hashes pinned).
  # Proxy/wrap mode intentionally unused (no traffic interception).
  modules.user.ai.caveman.enable = true;

  desktop.signal-desktop = {
    enable = true;
    passwordStore = "kwallet6";
  };

  # home.packages = [
  #   (pkgs.writeShellScriptBin "ssh-identities-check" (
  #     builtins.readFile ./packages/bin/ssh-identities-check
  #   ))
  # ];

  sops = {
    defaultSopsFile = ../../secrets/laptop.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };

  services.alpaca = lib.mkIf (v.pacUrl != null) {
    enable = true;
    pacUrl = v.pacUrl;
    username = v.workUser;
    domain = v.domain;
    port = 3129;
  };
}
