# hosts/laptop/packages/user.nix
# TODO: maybe declare the header definitions in user/system space and have
# a option attribute to append the list of desired packges from here.
{ inputs, pkgs, ... }:

let
  unstable = import inputs.unstable { inherit (pkgs.stdenv.hostPlatform) system; };
in
{
  imports = [
    ./unfree.nix
    ./insecure.nix
  ];

  # User packages
  home.packages =
    with pkgs;
    [
      nix
      home-manager

      dmidecode # Tool that reads information about your system's hardware from the BIOS according to the SMBIOS/DMI standard

      ytdownloader # Modern GUI video and audio downloader
      lrcsnc # Player-agnostic synced lyrics fetcher and displayer

      microfetch # Microscopic fetch script in Rust, for NixOS systems

      appflowy # Open-source alternative to Notion

      kdePackages.partitionmanager # Manage the disk devices, partitions and file systems on your computer
      kdePackages.kpmcore # KDE Partition Manager core library

      # TODO: Make a dedicated module for each browser
      # Browsers
      librewolf # Fork of Firefox, focused on privacy, security and freedom
      mullvad-browser # Privacy-focused browser made in a collaboration between The Tor Project and Mullvad
      tor-browser # Privacy-focused browser routing traffic through the Tor network
      thunderbird

      # Media
      vlc # Cross-platform media player
      unstable.mpc-qt # Media Player Classic Qute Theater
      mpv # General-purpose media player, fork of MPlayer and mplayer2

      # Office
      # libreoffice # Comprehensive, professional-quality productivity suite, a variant of openoffice.org
      onlyoffice-desktopeditors # Office suite that combines text, spreadsheet and presentation editors allowing to create, view and edit local documents
      # wpsoffice # Office suite, formerly Kingsoft Office

      # Messaging
      telegram-desktop # Telegram Desktop messaging app
      rocketchat-desktop # Official Desktop client for Rocket.Chat
      karere # Gtk4 Whatsapp client

      # VPN
      proton-vpn

      # Editors & IDEs
      # vscodium # Open source source code editor developed by Microsoft for Windows, Linux and macOS (VS Code without MS branding/telemetry/licensing)
      # vscode
      postman # API Development Environment
      jetbrains.datagrip # Database IDE from JetBrains
      dbeaver-bin # Universal SQL Client for developers, DBA and analysts. Supports MySQL, PostgreSQL, MariaDB, SQLite, and more
      dbgate # Database manager for MySQL, PostgreSQL, SQL Server, MongoDB, SQLite and others

      # Dev tools
      nodejs # Event-driven I/O framework for the V8 JavaScript engine
      direnv # Shell extension that manages your environment
      tree # Command to produce a depth indented directory listing
      bun # Incredibly fast JavaScript runtime, bundler, transpiler and package manager – all in one
      #       rustup # Rust toolchain installer
      gcc
      rust-analyzer
      gnumake # Tool to control the generation of non-source files from sources

      # System tools
      rustscan # Faster Nmap Scanning with Rust
      gptfdisk # Set of text-mode partitioning tools for Globally Unique Identifier (GUID) Partition Table (GPT) disks
      testdisk # Data recovery utilities
      gparted # Graphical disk partitioning tool

      # Archives
      zip
      xz
      unzip
      p7zip # New p7zip fork with additional codecs and improvements (forked from https://sourceforge.net/projects/p7zip/)
      unar # Archive unpacker program
      unrar # Utility for RAR archives

      # File systems
      gvfs # Virtual Filesystem support library
      usbutils # Tools for working with USB devices, such as lsusb
      udiskie # Removable disk automounter for udisks
      libmtp # Implementation of Microsoft's Media Transfer Protocol
      udisks # Daemon, tools and libraries to access and manipulate disks, storage devices and technologies

      # Networking
      mtr
      iperf3
      dnsutils
      ldns
      aria2
      socat
      ipcalc
      nmap # Free and open source utility for network discovery and security auditing

      # CLI utils
      cowsay
      file
      which
      gnused
      gnutar
      gawk
      zstd
      gnupg

      # Monitoring
      btop
      iotop
      iftop
      strace
      ltrace
      lsof
      sysstat
      lm_sensors
      ethtool
      pciutils

      # Graphics drivers (user-accessible)
      intel-media-driver # Intel Media Driver for VAAPI — Broadwell+ iGPUs
      intel-vaapi-driver # VA-API user mode driver for Intel GEN Graphics family
      libvdpau-va-gl # VDPAU driver with OpenGL/VAAPI backend
      vulkan-validation-layers
      libva-vdpau-driver
      libva # VAAPI library: Video Acceleration API
      mesa # Open source 3D graphics library

      bluetui # TUI for managing bluetooth on Linux

      alsa-lib # ALSA, the Advanced Linux Sound Architecture libraries
      libpulseaudio # Sound server for POSIX and Win32 systems
      pipewire # Server and user space API to deal with multimedia pipelines
      pavucontrol # PulseAudio Volume Control

      openssl # Cryptographic library that implements the SSL and TLS protocols

      ventoy # New Bootable USB Solution
      thunar # Xfce file manager
      unstable.gopeed # Modern download manager

      spotify # Play music from the Spotify music service
      tutanota-desktop # Tuta official desktop client
      kdePackages.dolphin # File manager by KDE
      kdePackages.okular # KDE document viewer
      kdePackages.ark # File archiver by KDE
      kdePackages.gwenview

      poppler-utils # PDF rendering library
      mov-cli # Cli tool to browse and watch movies
      ani-cli # Cli tool to browse and play anime
      scrcpy # Display and control Android devices over USB or TCP/IP
      spotiflac # Get Spotify tracks in true FLAC from Tidal, Qobuz & Amazon Music — no account required
    ]
    ++ [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
