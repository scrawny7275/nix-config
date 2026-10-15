# modules/user/security/certificates/assertions.nix
{ config, lib, ... }:

let
  cfg = config.security.certificates;
  policy = import ../../../shared/lib/certificates-policy.nix { inherit config lib; };
  enabledCas = lib.filterAttrs (n: v: v.enable) policy.cas;
in
{
  assertions =
    lib.mapAttrsToList (name: ca: {
      assertion = builtins.pathExists ca.certificate;
      message = "CA '${name}' certificate not found at ${toString ca.certificate}";
    }) enabledCas
    ++ lib.mapAttrsToList (name: ca: {
      assertion = lib.pipe ca.certificate [
        builtins.readFile
        (lib.strings.hasInfix "-----BEGIN CERTIFICATE-----")
      ];
      message = "CA '${name}' certificate does not appear to be in PEM format";
    }) enabledCas;
}
