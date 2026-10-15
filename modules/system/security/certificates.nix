# modules/system/security/certificates.nix
{ config, lib, ... }:

let
  cfg = config.security.certificates;
  policy = import ../../shared/lib/certificates-policy.nix { inherit config lib; };
  enabledCas = lib.filterAttrs (n: v: v.enable) policy.cas;
in
{
  imports = [ ../../shared/options/certificates.nix ];

  config = lib.mkIf cfg.enable {
    # System-wide trust store
    security.pki.certificateFiles = lib.mapAttrsToList (n: v: v.certificate) enabledCas;

    # Host-named files in /etc/ssl/certs/
    environment.etc = lib.mapAttrs' (n: v: {
      name = "ssl/certs/${v.installName}";
      value = {
        source = v.certificate;
      };
    }) enabledCas;
  };
}
