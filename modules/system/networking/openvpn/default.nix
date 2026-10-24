# modules/system/networking/openvpn/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  secretPath = name: config.sops.secrets."openvpn/${name}".path;
  profileUuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
  # VPN values from the private input (see modules/system/private.nix).
  # With the public stub (real = false): no server is defined at all.
  inherit (config.modules.private) values;
  on = config.modules.private.enable && values.vpnRemote != null;

in
{
  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openvpn ];
  };

  users.users.${values.userName}.extraGroups = [
    "networkmanager"
    "wheel"
  ];

  sops.secrets = {
    "openvpn/client-key" = {
      sopsFile = ./secrets/client.key.enc;
      format = "binary";
      mode = "0400";
    };
    "openvpn/client-cert" = {
      sopsFile = ./secrets/client.crt.enc;
      format = "binary";
      mode = "0400";
    };
    "openvpn/ca-cert" = {
      sopsFile = ./secrets/ca.crt.enc;
      format = "binary";
      mode = "0400";
    };
    "openvpn/tls-crypt" = {
      sopsFile = ./secrets/tls-crypt.key.enc;
      format = "binary";
      mode = "0400";
    };
    "openvpn/credentials" = {
      sopsFile = ./secrets/credentials.enc;
      format = "binary";
      mode = "0600";
    };
  };

  services.openvpn.servers.work = lib.mkIf on {
    config = ''
      client
      dev tun
      proto udp
      remote ${values.vpnRemote} 1194
      resolv-retry infinite
      nobind
      persist-key
      persist-tun
      remote-cert-tls server
      cipher AES-256-GCM
      auth SHA512
      verb 4

      key ${secretPath "client-key"}
      cert ${secretPath "client-cert"}
      ca ${secretPath "ca-cert"}
      tls-crypt ${secretPath "tls-crypt"}
      # auth-user-pass is injected automatically by authUserPass below
      auth-nocache

      mssfix 1280
      mute-replay-warnings
      keepalive 10 60
      sndbuf 0
      rcvbuf 0
      connect-retry 2 10
      connect-timeout 30
    '';

    authUserPass = secretPath "credentials";
    updateResolvConf = true;
    autoStart = true;
  };

  networking.networkmanager.ensureProfiles = lib.mkIf on {
    profiles = {
      "work-vpn" = {
        connection = {
          id = "Work VPN";
          uuid = profileUuid;
          type = "vpn";
          autoconnect = false;
        };

        vpn = {
          service-type = "org.freedesktop.NetworkManager.openvpn";
          connection-type = "password-tls"; # password + certificates
          dev = "tun";
          proto-udp = "yes";
          remote = "${values.vpnRemote}:1194";

          # Certificate paths (from sops-nix)
          ca = secretPath "ca-cert";
          cert = secretPath "client-cert";
          key = secretPath "client-key";
          tls-crypt = secretPath "tls-crypt";

          # Auth settings
          username = values.workUser; # Or use secrets if needed
          password-flags = "0"; # 1 = ask, 0 = system-store, 2 = not-required

          # Cipher & security (match your current config)
          cipher = "AES-256-GCM";
          auth = "SHA512";
          data-ciphers = "AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305";
          remote-cert-tls = "server";

          # Additional options from your config
          mssfix = "1280";
          keepalive = "10 60";
          sndbuf = "0";
          rcvbuf = "0";
          connect-retry = "2 10";
          connect-timeout = "30";
          persist-key = "yes";
          persist-tun = "yes";
          resolv-retry = "infinite";
          nobind = "yes";
          verb = "4";
        };

        ipv4 = {
          method = "auto";
          may-fail = false;
        };

        ipv6 = {
          method = "auto";
        };
      };
    };

    secrets.entries = [
      {
        matchId = "Work VPN";
        matchType = "vpn";
        matchSetting = "vpn";
        key = "password";
        file = secretPath "credentials";
      }
    ];
  };

  boot.kernelModules = [ "tun" ];

  systemd.services."openvpn-work" = lib.mkIf on {
    after = [ "sops-nix.service" ];
    serviceConfig.RestartSec = "5";
  };
}
