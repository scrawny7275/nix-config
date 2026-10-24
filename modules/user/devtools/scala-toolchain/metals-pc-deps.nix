# modules/user/devtools/scala-toolchain/metals-pc-deps.nix
#
# Fixed-output derivation pinning the Scala 3 presentation-compiler
# artifact set that Metals fetches at runtime.
#
# Why this exists:
#   Metals does NOT bundle a Scala 3 presentation compiler. For Scala
#   >= 3.3.4-RC1 (MtagsResolver "StablePC" path) it fetches
#   org.scala-lang:scala3-presentation-compiler_3:<full-scala-version>
#   (transitively scala3-compiler_3, scala3-library_3, tasty-core_3,
#   mtags-interfaces, lsp4j, jline, ...) via its embedded coursier,
#   which honors COURSIER_REPOSITORIES.
#
#   With nexus-first repos, a truncated checksum-less jar from the
#   corporate proxy poisoned the coursier cache and crashed every
#   Scala 3 file with:
#     ClassNotFoundException: dotty.tools.dotc.interactive.InteractiveDriver
#
#   This derivation downloads the full closure from Maven Central,
#   verifies every artifact against the pinned SHA-1 in
#   metals-pc-manifest.txt, and lays it out as a coursier v1 cache.
#   The wrapper seeds a private cache from this store path, so
#   Metals' runtime fetch becomes a pure, hash-locked cache hit and
#   the corporate proxy is structurally bypassed for this artifact set.
#
# Why a manifest instead of `cs fetch`:
#   Coursier's own resolution is version-range-driven and re-resolves
#   on every run; a static manifest is reproducible by construction
#   (like a lockfile) and needs only curl, which supports -C -
#   (resume) — the nixpkgs `cs` launcher also bootstraps its CLI from
#   the network on first use, which is fragile in sandboxes.
#
# The manifest is generated from the Maven POM closure (see module
# docs); every entry: <repo-path>|<sha1>|<bytes>|<url>. It includes
# both PC 3.3.6 (project target) and 3.3.7 (Metals standalone-fallback
# version) so the fallback path is also offline-capable.
#
# Updating:
#   When bumping Scala/Metals versions, regenerate the manifest (see
#   metals-wrapper.nix docs), then rebuild and paste the "got:" hash
#   from the expected mismatch into outputHash (same workflow as
#   nixpkgs pkgs/by-name/me/metals/update.nix).
{
  lib,
  stdenv,
  curl,
  cacert,
  # JDK only for the jar-tf integrity gate; the toolchain standard.
  jdk17,
  # Private-mirror coursier cache keys to additionally seed (empty: none).
  nexusMirrorKeys ? [ ],
}:

stdenv.mkDerivation {
  name = "metals-pc-deps";

  # Every artifact path|sha1|bytes|url, one per line, tracked in-repo.
  manifest = ./metals-pc-manifest.txt;

  buildCommand = ''
    set -euo pipefail
    export HOME="$PWD"
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    manifest="${./metals-pc-manifest.txt}"

    # v1-cache layout under a throwaway dir; replicated into $out at
    # the end. The .checked markers make coursier treat releases as
    # recently verified (avoids TTL revalidation network probes).
    CACHE_ROOT="$PWD/cache/v1/https/repo1.maven.org/maven2"
    mkdir -p "$CACHE_ROOT"

    # Parallel fetch: 8 workers, each owning one artifact end-to-end
    # (download -> mirror-chain resume -> size/sha1 gates -> coursier
    # sidecars -> jar sanity). A flaky route stalls only its own
    # artifact instead of serializing the whole set behind 12 x 300s
    # of retries. Central is canonical but route-flaky from some
    # networks; the public mirrors carry identical bytes (sha1-verified
    # per worker) and -C - lets a stall on one mirror resume on the
    # next.
    CURL="${curl}/bin/curl"
    JAR="${jdk17}/bin/jar"
    FAILLOG="$PWD/failures.log"
    : > "$FAILLOG"
    export CACHE_ROOT FAILLOG CURL JAR

    cat > fetch-one.sh <<'WORKER'
    #!/usr/bin/env bash
    set -u
    IFS='|' read -r rel sha1 size url <<< "$1"
    dst="$CACHE_ROOT/$rel"
    mkdir -p "$(dirname "$dst")"
    ok=0
    MIRRORS="https://repo1.maven.org/maven2 https://repo.huaweicloud.com/repository/maven https://maven.aliyun.com/repository/public"
    for mirror in $MIRRORS; do
      for attempt in 1 2 3; do
        if "$CURL" -sS -f -L --connect-timeout 10 --max-time 150 \
             --speed-time 25 --speed-limit 1024 -C - -o "$dst" "$mirror/$rel"; then
          ok=1
          break 2
        fi
        echo "retry $attempt via $mirror for $rel" >&2
        sleep 1
      done
    done
    if [ "$ok" != "1" ]; then
      echo "FAILED to download $rel" >> "$FAILLOG"
      exit 1
    fi

    # Integrity gates: size then sha1, both from the manifest.
    actual_size=$(stat -c%s "$dst")
    if [ "$actual_size" != "$size" ]; then
      echo "SIZE MISMATCH $rel: expected $size got $actual_size" >> "$FAILLOG"
      exit 1
    fi
    actual_sha=$(sha1sum "$dst" | cut -d' ' -f1)
    if [ "$actual_sha" != "$sha1" ]; then
      echo "SHA1 MISMATCH $rel: expected $sha1 got $actual_sha" >> "$FAILLOG"
      rm -f "$dst"
      exit 1
    fi

    # Coursier sidecar files, mirroring what a real fetch writes:
    # checksum sidecar + .checked marker so runtime resolution
    # treats these as verified releases without network access.
    dir="$(dirname "$dst")"
    base="$(basename "$dst")"
    printf '%s' "$sha1" > "$dir/.$base"'__sha1'
    printf '%s' "$sha1" > "$dir/.$base"'__sha1.computed'
    printf '%s' "$sha1" > "$dir/$base.sha1"
    touch "$dir/.$base.checked"

    # Zip central-directory sanity for jars only (POMs are XML; sha1
    # already catches truncation; belt and suspenders).
    case "$dst" in
      *.jar) "$JAR" tf "$dst" > /dev/null ;;
    esac
    WORKER

    # Manifest lines contain no spaces, so each reaches xargs as a
    # single argument. A worker failure must not abort the batch
    # (set -e + xargs exit 123): it lands in FAILLOG, gated below.
    xargs -P 8 -n 1 bash fetch-one.sh < "$manifest" || true
    if [ -s "$FAILLOG" ]; then
      cat "$FAILLOG" >&2
      exit 1
    fi

    # Presence pass + count (integrity already proven per worker).
    n=0
    while IFS='|' read -r rel sha1 size url; do
      [ -n "$rel" ] || continue
      [ -f "$CACHE_ROOT/$rel" ] || { echo "MISSING after fetch: $rel" >&2; exit 1; }
      n=$((n + 1))
    done < "$manifest"

    # Mirror the fetched tree into the private-mirror cache keys. Coursier
    # keys cache entries per-repository-URL and checks repos in declared
    # order; on-VPN resolution walks mirror paths first, so seeded
    # entries there prevent mirror re-fetches of this pinned set.
    # (The sonatype-snapshots key that Embedded.repositories appends is
    # added by the pure pcCacheLayout derivation in metals-wrapper.nix.)
    # Mirror keys come from the private input (stub: none).
    ${lib.optionalString (nexusMirrorKeys != [ ]) ''
      for nexusKey in ${lib.concatMapStringsSep " " lib.escapeShellArg nexusMirrorKeys}; do
        mirror="$PWD/cache/v1/https/$nexusKey"
        mkdir -p "$mirror"
        cp -a "$CACHE_ROOT/." "$mirror/"
      done
    ''}

    mkdir -p "$out/v1"
    cp -a "$PWD/cache/v1/." "$out/v1/"
    # Writable perms: coursier takes structure locks inside the cache
    # root even on pure hits; store default would be read-only.
    chmod -R u+rwX "$out/v1"

    echo "metals-pc-deps: fetched and verified $n artifacts"
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-2S5iKI4bfe2f0JCjnXkdToEkyEd7sH1tw9eniT+MM+w=";
}
