# modules/user/security/certificates/default.nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.security.certificates;
  policy = import ../../../shared/lib/certificates-policy.nix { inherit config lib; };
  enabledCas = lib.filterAttrs (n: v: v.enable) policy.cas;
  cacerts = import ../../../shared/lib/build-cacerts.nix { inherit pkgs lib policy; };
in
{
  imports = [
    ../../../shared/options/certificates.nix
    ./assertions.nix
  ];

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Combined JVM trust store
      (lib.mkIf (cacerts.combinedJks != null) {
        xdg.configFile."nix/cacerts".source = cacerts.combinedJks;
      })

      # Combined PEM for curl/Go/Node/Python
      (lib.mkIf (cacerts.combinedPem != null) {
        home.sessionVariables = {
          SSL_CERT_FILE = lib.mkDefault cacerts.combinedPem;
          CURL_CA_BUNDLE = lib.mkDefault cacerts.combinedPem;
          NODE_EXTRA_CA_CERTS = lib.mkDefault cacerts.combinedPem;
          REQUESTS_CA_BUNDLE = lib.mkDefault cacerts.combinedPem;
        };
      })

      # Per-CA manual install paths (host-defined filenames)
      {
        home.file = lib.mapAttrs' (n: v: {
          name = ".local/share/ca-certificates/${v.installName}";
          value = {
            source = v.certificate;
          };
        }) enabledCas;
      }
    ]
  );
}
