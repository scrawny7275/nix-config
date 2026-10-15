# modules/shared/lib/build-cacerts.nix
{
  pkgs,
  lib,
  policy,
}:

let
  enabledCas = lib.filterAttrs (n: v: v.enable) policy.cas;
  caCertPaths = lib.mapAttrsToList (n: v: v.certificate) enabledCas;

  buildJks =
    {
      name,
      certs,
      jdk ? pkgs.jdk,
    }:
    let
      certImports = lib.concatMapStrings (cert: ''
        cat ${cert} >> "$TMPDIR/all-certs.pem"
      '') certs;
    in
    pkgs.runCommand "${name}.jks"
      {
        nativeBuildInputs = [ jdk ];
        STOREPASS = policy.javaTrustStorePassword;
      }
      ''
        set -euo pipefail

        cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > "$TMPDIR/all-certs.pem"
        ${certImports}

        ${jdk}/bin/keytool -genkey -keyalg RSA -alias temp -keystore "$out" \
          -storepass "$STOREPASS" -keypass "$STOREPASS" \
          -dname "CN=temp" -validity 1
        ${jdk}/bin/keytool -delete -alias temp -keystore "$out" -storepass "$STOREPASS"

        awk -v tmpdir="$TMPDIR" '
          BEGIN { n = 0 }
          /-----BEGIN CERTIFICATE-----/ { n++; outfile = tmpdir "/cert-" n ".pem" }
          outfile { print > outfile }
        ' "$TMPDIR/all-certs.pem"

        for cert in "$TMPDIR"/cert-*.pem; do
          [ -e "$cert" ] || continue
          alias=$(basename "$cert" .pem)
          ${jdk}/bin/keytool -importcert \
            -alias "$alias" \
            -file "$cert" \
            -keystore "$out" \
            -storepass "$STOREPASS" \
            -noprompt \
            -trustcacerts
        done

        count=$(${jdk}/bin/keytool -list -keystore "$out" -storepass "$STOREPASS" | grep -c "Entry" || true)
        if [ "$count" -eq 0 ]; then
          echo "ERROR: JKS trust store was created but contains 0 entries" >&2
          exit 1
        fi
        echo "JKS trust store created with $count entries"
      '';

  buildPemBundle =
    certs:
    let
      certImports = lib.concatMapStrings (cert: ''
        cat ${cert} >> "$out"
      '') certs;
    in
    pkgs.runCommand "ca-bundle-custom.pem" { } ''
      cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > "$out"
      ${certImports}
    '';

in
{
  combinedJks =
    if caCertPaths != [ ] then
      buildJks {
        name = "combined-cacerts";
        certs = caCertPaths;
      }
    else
      null;

  combinedPem = if caCertPaths != [ ] then buildPemBundle caCertPaths else null;

  jksFor =
    cert: name:
    buildJks {
      inherit name;
      certs = [ cert ];
    };
  pemFor = cert: name: buildPemBundle [ cert ];
}
