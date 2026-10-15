# modules/user/devtools/scala-toolchain/metals-wrapper.nix
#
# Reusable Metals launcher with a hash-locked Scala 3 presentation
# compiler cache.
#
# Mechanism (verified against Metals 1.6.7 + its embedded coursier
# 2.1.25-M23 bytecode):
#   - Metals does NOT bundle a Scala 3 PC. For Scala >= 3.3.4-RC1 it
#     fetches org.scala-lang:scala3-presentation-compiler_3:<version>
#     at runtime via embedded coursier.
#   - Embedded coursier honors COURSIER_REPOSITORIES and COURSIER_CACHE
#     env vars (CoursierEnv$.defaultRepositories / CacheEnv), so this
#     wrapper controls both.
#   - Coursier keys its v1 cache per-repository-URL and walks repos in
#     declared order; a cache seeded under every repo key turns the
#     runtime fetch into a pure local hit.
#
# What this module provides:
#   1. ~/.local/bin/metals-wrapper — the launcher every editor should
#      use (Zed does; opencode is wired to it). Exports the corporate
#      SSL truststore, a fast connect timeout (fail fast to next repo
#      when nexus black-holes off-VPN), a 30s per-read timeout (a socket
#      that accepts then sends nothing must not hang coursier at 0%
#      forever — failure mode 3), and points COURSIER_CACHE at a
#      private seeded dir.
#   2. metals-pc-deps FOD — hash-locked PC artifact set from Central
#      (see metals-pc-deps.nix), seeded into the private cache at
#      every home-manager switch (overwrite = corruption self-heal).
#   3. Integrity sweep of the DEFAULT coursier cache (~/.cache/coursier,
#      used by sbt): any org/scala-lang or org/scalameta jar that fails
#      jar-tf is deleted with its sidecars so the next fetch repairs it.
#      This is the recovery path for the truncated-jar class of nexus
#      failure that broke sbt too.
#   4. BSP shims (~/.local/bin/sbt-bsp, scala-cli-bsp) that strip
#      COURSIER_CACHE before exec'ing the real build tool, keeping
#      Metals' private cache isolated from sbt/scala-cli child
#      processes (they keep their default cache + nexus resolvers).
{
  config,
  pkgs,
  lib,
  ...
}:

let
  certPolicy = import ../../../shared/lib/certificates-policy.nix { inherit config lib; };
  certs = config.security.certificates;

  # Hash-locked Scala 3 PC artifact set (3.3.6 target + 3.3.7 fallback).
  pcDeps = pkgs.callPackage ./metals-pc-deps.nix {
    inherit (config.modules.private.values) nexusMirrorKeys;
  };

  # Multi-repo-key cache layout. Coursier keys its v1 cache
  # per-repository-URL and walks repositories in declared order; every
  # repo the runtime can consult must hold a seeded copy or resolution
  # re-fetches through it. Embedded coursier consults (in order):
  #   1. COURSIER_REPOSITORIES env (ivy2Local, central, nexus, nexus-3 —
  #      see coursierRepos below)
  #   2. ~/.m2/repository (mavenLocal)
  #   3. central.sonatype.com/repository/maven-snapshots (appended
  #      unconditionally by Metals' Embedded.repositories)
  # All keys hold byte-identical, sha1-verified content, so hits are
  # pure regardless of which repo wins the walk. Pure derivation: cp
  # from the FOD store path, no network, fully deterministic.
  pcCacheLayout = pkgs.runCommand "metals-pc-cache-layout" { } ''
    mkdir -p "$out/v1/https"
    for repoKey in \
      "repo1.maven.org/maven2" \
      ${lib.concatMapStringsSep " \\\n      " lib.escapeShellArg config.modules.private.values.nexusMirrorKeys} \
      "central.sonatype.com/repository/maven-snapshots"; do
      mkdir -p "$out/v1/https/$repoKey"
      cp -a "${pcDeps}/v1/https/repo1.maven.org/maven2/." \
        "$out/v1/https/$repoKey/"
    done
    chmod -R u+rwX "$out/v1"
  '';

  # JDK-level network flags, exported via the wrapper's JAVA_TOOL_OPTIONS
  # (metals-wrapper.nix). Two classes:
  #   1. sslFlags (below): corporate truststore for nexus TLS.
  #   2. dnsTtlFlags (below): cap JVM DNS caching of negative results
  #      (NXDOMAIN) to 10s and positive to 30s. Default JVM negative TTL
  #      can outlive a VPN connect/disconnect and keep Metals pointing
  #      at a dead nexus for the process lifetime. These flags make DNS
  #      state changes propagate within one import cycle.
  dnsTtlFlags = "-Dnetworkaddress.cache.ttl=30 -Dnetworkaddress.cache.negative.ttl=10";

  sslFlags = lib.optionalString certs.enable (
    lib.concatStringsSep " " [
      "-Djavax.net.ssl.trustStorePassword=${certPolicy.javaTrustStorePassword}"
      "-Djavax.net.ssl.trustStore=${config.xdg.configHome}/nix/cacerts"
    ]
  );

  # Repo list mirrors hosts/laptop/home.nix COURSIER_REPOSITORIES — it is
  # supplied by the same private private input (stub: ivy2Local|central).
  # central FIRST (publicly reachable from any network; the private cache
  # is seeded from Central so hits work off-VPN), mirrors after. Coursier
  # walks in order and falls through past unreachable repos, so
  # mirror-first caused NXDOMAIN timeouts to block before central (where
  # the seed lives) was ever tried.
  coursierRepos = config.modules.private.values.coursierRepositories;

  # Private, seeded cache dir for Metals' embedded coursier. COURSIER_CACHE
  # must point at the v1 layout root itself (coursier appends /v1-relative
  # keys under it): the FOD output keeps "$out/v1/https/..." and the seed
  # copies v1/. over this dir, so cache files end up at
  # <metalsCache>/https/<repo-key>/... — exactly where embedded coursier
  # looks (verified: FileCache resolves cacheLocation()/v1/https/...).
  metalsCache = "${config.xdg.cacheHome}/metals-coursier/v1";

  # JDK used by activation for the jar-tf integrity gate (same toolchain
  # standard as the rest of the config).
  jdk = config.devtools.java.selectedJdk;

  seedScript = pkgs.writeShellScript "metals-seed-cache" ''
    set -euo pipefail
    target="${metalsCache}"
    src="${pcCacheLayout}/v1"

    # Idempotent seed: fresh copy each switch overwrites whatever the
    # runtime left behind (including any corrupted re-downloads), so the
    # cache converges to the hash-locked set on every switch.
    # A previous run or manual cp -a from the store may have left the
    # tree read-only; make it writable (and removable) first.
    if [ -e "$target" ]; then
      chmod -R u+rwX "$target" || true
    fi
    mkdir -p "$target"
    # cp without -a: plain files land writable (coursier takes structure
    # locks inside the cache even on pure hits).
    cp -r "$src/." "$target/"
    chmod -R u+rwX "$target"

    # Seed the DEFAULT coursier cache (sbt's cache) with the same pinned
    # set under the central key. sbt resolves PC/compiler deps through
    # its own coursier with its own resolvers; off-VPN this lets it hit
    # the pinned jars instead of timing out against nexus. Merge only:
    # never delete, never touch non-PC paths (the sweep below only
    # removes jars that fail `jar tf`).
    defcc="$HOME/.cache/coursier/v1/https/repo1.maven.org/maven2"
    if [ -d "$HOME/.cache/coursier/v1/https" ]; then
      mkdir -p "$defcc"
      cp -r "$src/https/repo1.maven.org/maven2/." "$defcc/"
      chmod -R u+rwX "$defcc"
    fi

    # Integrity sweep of the DEFAULT coursier cache (sbt's cache).
    # Only org/scala-lang and org/scalameta main jars; sources/javadoc
    # excluded (Metals never loads them from these groups).
    cc="$HOME/.cache/coursier/v1/https"
    if [ -d "$cc" ]; then
      find "$cc" -type f -name "*.jar" \
        \( -path "*/org/scala-lang/*" -o -path "*/org/scalameta/*" \) \
        ! -name "*-sources.jar" ! -name "*-javadoc.jar" \
        -print0 |
      while IFS= read -r -d "" jarfile; do
        if ! ${jdk}/bin/jar tf "$jarfile" > /dev/null 2>&1; then
          echo "metals-wrapper: corrupt jar removed: $jarfile" >&2
          rm -f "$jarfile" "$jarfile.sha1" "$jarfile.lock" \
            "$(dirname "$jarfile")/.$(basename "$jarfile").checked" \
            "$(dirname "$jarfile")/.$(basename "$jarfile")__sha1" \
            "$(dirname "$jarfile")/.$(basename "$jarfile")__sha1.computed"
        fi
      done
    fi
    echo "metals-wrapper: cache seeded at $target"
  '';

  # Shim: strip Metals' private cache env before exec'ing the build tool.
  # For scala-cli, a simple passthrough suffices.
  scalaCliBspShim = pkgs.writeShellScriptBin "scala-cli-bsp-inner" ''
    unset COURSIER_CACHE
    exec ${pkgs.scala-cli} "$@"
  '';

  # Managed sbt BSP launcher: checks for stale sbt background daemons,
  # kills them if old enough, then launches sbt BSP. This is the
  # declarative fix for the "sbt daemon blocks BSP" failure mode.
  sbtBspWrapper = pkgs.writeShellScriptBin "sbt-bsp-inner" ''
    set -euo pipefail

    # The project dir is the CWD (Metals sets this when launching BSP).
    PROJECT_DIR="''${PWD:?sbt-bsp: PWD not set}"

    # Find stale sbt processes for this project (>10 min old).
    # Match any sbt-launch.jar process (BSP or background daemon).
    # Age via `etimes` (seconds) — never parse `etime` (MM:SS vs HH:MM
    # ambiguity made the gate fire at ~1 min; live bug, fixed).
    kill_stale_sbt() {
      local pid cwd esec
      for pid in $(pgrep -f 'sbt-launch\.jar' 2>/dev/null || true); do
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
        [ "$cwd" = "$PROJECT_DIR" ] || continue
        esec=$(ps -o etimes= -p "$pid" 2>/dev/null | xargs || true)
        [ -n "$esec" ] || continue
        if [ "$esec" -ge 600 ]; then
          echo "sbt-bsp: killing stale sbt daemon pid $pid ($((esec / 60))min old, $PROJECT_DIR)" >&2
          kill "$pid" 2>/dev/null || true
        fi
      done
    }

    kill_stale_sbt
    unset COURSIER_CACHE
    exec ${pkgs.sbt} "$@"
  '';
in
{
  # Coursier stays on PATH for Metals' CLI fallback path
  # (Embedded.fallbackDownload shells out to `cs`).
  home.packages = [ pkgs.coursier ];

  home.file.".local/bin/metals-wrapper" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      # Metals launcher — editor-agnostic (Zed, opencode, any LSP client).
      # 1. Corporate SSL truststore for nexus access.
      # 2. Fast connect timeout (fails over to the next repo quickly when
      #    nexus black-holes off-VPN) PLUS a generous per-read timeout:
      #    with connect-only, a socket that accepts then delivers 0 bytes
      #    hangs coursier forever at "0.00 %, 0 / N" (failure mode 3).
      #    30s between reads still survives slow large-jar mirrors.
      # 3. Private seeded COURSIER_CACHE: Scala 3 PC fetches are pure local
      #    hits from the hash-locked metals-pc-deps set.
      # 4. COURSIER_TTL: without it coursier revalidates every cached
      #    release online on each resolution (checkNeeded defaults true);
      #    a long TTL keeps the seeded set a pure hit.
      # 5. dnsTtlFlags: DNS cache caps so VPN connect/disconnect
      #    propagates to the running JVM within seconds, not process
      #    lifetime (see dnsTtlFlags above).
      export JAVA_TOOL_OPTIONS="${sslFlags} ${dnsTtlFlags} -Dsun.net.client.defaultConnectTimeout=5000 -Dsun.net.client.defaultReadTimeout=30000"
      export COURSIER_CACHE="${metalsCache}"
      export COURSIER_REPOSITORIES="${coursierRepos}"
      export COURSIER_TTL="720h"
      # Run inside a user systemd scope when possible: cgroup membership
      # survives reparenting, so when the EDITOR kills this wrapper (LSP
      # shutdown) or metals-repair kills the scope wholesale, every
      # descendant dies with it — including Metals' coursier fallback
      # children that used to orphan and spin for hours holding cache
      # locks (observed live: 15h `cs fetch` orphan, PID outside any
      # project-cwd matcher). Verified on systemd 260: stub TERM forwards
      # to child; stub KILL collects the scope; kill --kill-whom=all
      # reaches setsid'd orphans. No resource caps yet — measure first.
      # Falls back to plain exec headless/no-dbus so LSP always starts.
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v systemd-run >/dev/null 2>&1; then
        scope_proj=$(basename "''${PWD:-unknown}" 2>/dev/null | tr -c 'a-zA-Z0-9_.' '-' || echo unknown)
        exec systemd-run --user --scope --quiet --collect \
          --unit="metals-''${scope_proj}-$$" \
          -- ${lib.getExe pkgs.metals} "$@" \
          2>/dev/null || exec ${lib.getExe pkgs.metals} "$@"
      fi
      exec ${lib.getExe pkgs.metals} "$@"
    '';
  };

  # BSP entry points Zed passes to Metals (sbtScript / scalaCliLauncher):
  # keeps sbt/scala-cli child processes on the DEFAULT coursier cache and
  # their own resolvers, isolated from Metals' private cache.
  home.file.".local/bin/sbt-bsp" = {
    executable = true;
    source = "${sbtBspWrapper}/bin/sbt-bsp-inner";
  };
  home.file.".local/bin/scala-cli-bsp" = {
    executable = true;
    source = "${scalaCliBspShim}/bin/scala-cli-bsp-inner";
  };

  # Seed + sweep on every switch. Runs in the foreground: the seed is a
  # local store copy (~200 MB) and completes in seconds; the sweep is
  # bounded to two artifact groups.
  home.activation.metals-pc-cache = lib.mkAfter ''
    ${seedScript}
  '';
}
