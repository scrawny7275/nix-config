# hosts/laptop/system.nix
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  inputs,
  pkgs,
  ...
}:

let
  # Personal + employer values flow from the private `private` input
  # (stub unless --override-input private ...). See modules/system/employer.nix.
  v = config.modules.private.values;
  # Real hardware scan (disk UUIDs) ships only in the private input; the public
  # repo carries a generic skeleton. NOTE: `imports` may not depend on `config`
  # (module-system recursion), so this read is straight from the input path —
  # pure-eval-safe because the path lives INSIDE the input.
  employerInput = inputs.private;
  privateHw = employerInput + "/hardware.nix";
  privateValues = import (employerInput + "/values.nix");
  hardwareFile = if privateValues.real && builtins.pathExists privateHw then privateHw else ./hardware.nix;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    hardwareFile # Machine hardware scan (private input overrides the skeleton).
    ./packages/system.nix

    ../../modules/system/private.nix
    ../../modules/system/bootloader.nix

    ../../modules/system/nix/settings.nix
    ../../modules/system/nix/caches.nix
    ../../modules/system/nix/nix-ld.nix
    ../../modules/system/nix/gc-roots.nix

    ../../modules/system/security/certificates.nix
    ../../modules/system/security/polkit-disk.nix

    ../../modules/system/networking
    ../../modules/system/networking/cntlm.nix
    ../../modules/system/networking/bluetooth.nix
    ../../modules/system/networking/openvpn
    ../../modules/system/networking/hosts.nix
    ../../modules/system/networking/proxy.nix
    ./proxy-options.nix
    ../../modules/system/networking/protonvpn

    ../../modules/system/shell.nix

    ../../modules/system/desktop/cosmic.nix
    ../../modules/system/desktop/plasma.nix
    ../../modules/system/desktop/uwsm.nix
    ../../modules/system/desktop/x11.nix
    ../../modules/system/app/brave
  ];

  networking.hostName = "nixos";

  security.certificates.policyFile = ./policy.nix;

  services.fprintd.enable = true;

  services.envfs.enable = true;

  system.activationScripts.gcroots = ''
    mkdir -p /nix/var/nix/gcroots/manual
    ${pkgs.nix}/bin/nix-store --add-root /nix/var/nix/gcroots/manual/current-system --indirect -r /nix/var/nix/profiles/system
  '';

  sops = {
    defaultSopsFile = ../../secrets/laptop.yaml;
    age = {
      generateKey = true; # Auto-generate if missing
      keyFile = "/var/lib/sops-nix/keys.txt"; # System-wide, not in home (user-space)
    };
  };

  # Set your time zone.
  # time.timeZone = "America/New_York"; # Manage by localtimed services

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  console = {
    earlySetup = true;
    keyMap = "la-latin1";
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v24b.psf.gz";
    packages = with pkgs; [ terminus_font ];
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable udev for hardware events
  services.udev.enable = true;

  # Required for desktop portals and GUI apps
  services.dbus.enable = true;

  # Polkit
  security.polkit.enable = true;

  services.upower.enable = true;

  # XDG Desktop Portal configured in modules/user/desktop/xdg/portal.nix

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${v.userName} = {
    isNormalUser = true;
    description = v.fullName;
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "storage"
    ];
  };

  users.users.cntlm = {
    group = "cntlm";
    isSystemUser = true;
  };
  users.groups.cntlm = { };

  fonts.packages = with pkgs; [
    terminus_font
    nerd-fonts._0xproto
    nerd-fonts.droid-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.ubuntu-mono
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.code-new-roman # Nerd Fonts: Tunable, slashed zeros, compact smaller characters
    nerd-fonts.meslo-lg # Nerd Fonts: Slashed zeros, customized version of Apple's Menlo
    font-awesome # Font Awesome - OTF font
    roboto
    noto-fonts-lgc-plus # Beautiful and free fonts for many languages
    noto-fonts-cjk-sans # Beautiful and free fonts for CJK languages
    noto-fonts-cjk-serif # Beautiful and free fonts for CJK languages
    noto-fonts-emoji-blob-bin # Noto Emoji with extended Blob support
    noto-fonts-monochrome-emoji # Monochrome emoji font
    liberation_ttf # Liberation Fonts, replacements for Times New Roman, Arial, and Courier New
    dejavu_fonts # Typeface family based on the Bitstream Vera fonts
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # hardware.bluetooth.enable = true;
  # hardware.bluetooth.powerOnBoot = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime-legacy1
      intel-media-driver # Intel Media Driver for VAAPI — Broadwell+ iGPUs
      intel-vaapi-driver # VA-API user mode driver for Intel GEN Graphics family
      libvdpau-va-gl # VDPAU driver with OpenGL/VAAPI backend
      vulkan-validation-layers
      libva-vdpau-driver
      libva # VAAPI library: Video Acceleration API
      mesa # Open source 3D graphics library
    ];
    enable32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };
  hardware.cpu.intel.updateMicrocode = true;

  nix.settings.trusted-users = [
    "root"
    v.userName
  ];

  services.frigate.vaapiDriver.enable = "vdpau";

  services.udisks2.enable = true;

  # Soteria is a Polkit authentication agent written in GTK designed to be used with any desktop environment.
  # security.soteria.enable = true;

  # services.localtimed.enable = true;

  # networking.useDHCP = lib.mkForce true;
  # networking.interfaces.enp0s31f6.useDHCP = false;
  # networking.interfaces.enp0s31f6.ipv4.addresses = [
  #   {
  #     # address = "192.0.2.10";
  #     address = "192.0.2.20"; # documentation range (RFC 5737)
  #     prefixLength = 24;
  #   }
  # ];
  # networking.defaultGateway = "192.0.2.1";
  # networking.nameservers = [
  #   "192.0.2.2"
  #   "192.0.2.3"
  # ];

  environment.sessionVariables = { };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  # networking.firewall.trustedInterfaces = [ "tun0" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
