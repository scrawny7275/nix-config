# modules/system/networking/protonvpn/default.nix
{ config, ... }:

{
  sops.secrets."wireguard/proton_private_key" = {
    sopsFile = ../../../../secrets/laptop.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.wg-quick.interfaces.proton = {
    autostart = false; # Set to true if you want it to connect on boot

    # Interface settings (from [Interface])
    address = [
      "10.2.0.2/32"
      "2a07:b944::2:2/128"
    ];
    privateKeyFile = config.sops.secrets."wireguard/proton_private_key".path;
    dns = [
      "10.2.0.1"
      "2a07:b944::2:1"
    ];

    # Peer settings (from [Peer])
    peers = [
      {
        publicKey = "Y46WhKEXcCGgPn+LXHDrlD93hgVzrA2mju7XQBbyyXU=";
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        endpoint = "149.88.97.97:51820";
        persistentKeepalive = 25;
      }
    ];
  };
}
