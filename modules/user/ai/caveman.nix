# modules/user/ai/caveman.nix
# Caveman CLI + signed Go runtime companions, packaged declaratively
# (replaces the vendor's imperative `caveman setup --install` path).
# Scope intentionally narrow: token metering/analyzer (`caveman learn`).
# The traffic-intercepting proxy (`caveman start` / wrap) is NOT in scope —
# binaries exist on disk but nothing routes traffic through them unless
# explicitly invoked. Adopted 2026-09-26 after empty-subagent spawns on
# kimi-k3 made quota visibility a recurring need.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.user.ai.caveman;

  # Binaries: vendor-signed release, hashes pinned via nix-prefetch-url.
  # Upgrade = bump release + re-prefetch hashes (Nix-controlled cadence).
  release = "bin-v1.1.7";
  binBase = "https://github.com/JuliusBrussee/caveman/releases/download/${release}";
  plat = "linux_amd64";
  bins = {
    caveman-proxy = "1kp18h082bbx4rwcifmf2gm9mhnp6c0yyrjyclzsl6kysziajrrv";
    caveman-engine = "1fiq7fnyyqkfnznpy02z4xja1kgadw4kcvxhwmx98n3brkq6fj2a";
    caveman-mcp = "07qb99j2xmyp28l45399f57x2lfssfcp6jwry9z17zijjqwm5k2f";
    cavemem = "0kp2q875zin8sf941j3brl4420xxyq70ds1bqhvarzsww644k4gz";
  };

  cavemanBinaries = pkgs.runCommand "caveman-binaries-${release}" { } ''
    mkdir -p $out/bin
    ${concatStringsSep "\n" (
      mapAttrsToList (
        name: hash:
        "install -Dm755 ${
          pkgs.fetchurl {
            url = "${binBase}/${name}_${plat}";
            sha256 = hash;
          }
        } $out/bin/${name}"
      ) bins
    )}
  '';

  # CLI: npm tarball has zero runtime dependencies (verified via npm view),
  # so a plain node wrapper suffices — no npm/bundling machinery.
  cavemanCli = pkgs.stdenvNoCC.mkDerivation {
    pname = "caveman-cli";
    version = "1.3.4";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@caveman-ai/cli/-/cli-1.3.4.tgz";
      sha256 = "0g7slms8pa5cc37cxa7wng12h58xm69d51yf5ijb5hw3lyzqs1ih";
    };
    sourceRoot = "package";
    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/caveman-cli $out/bin
      cp -R . $out/lib/caveman-cli/
      # PATH prefix: cavemanBin(name, envVar) lookup order is env -> PATH -> ~/.caveman/bin
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/caveman \
        --add-flags "$out/lib/caveman-cli/dist/index.js" \
        --prefix PATH : ${cavemanBinaries}/bin
      ln -s $out/bin/caveman $out/bin/cave
      runHook postInstall
    '';
    meta.description = "Caveman CLI driver + pinned Go runtime binaries";
  };
in
{
  options.modules.user.ai.caveman = {
    enable = mkEnableOption "Caveman CLI (token sink analysis) + pinned Go binaries";

    dataDir = mkOption {
      type = types.str;
      # Tool-internal default (cavemanHome()); HM pre-creates it declaratively.
      default = "${config.home.homeDirectory}/.caveman";
      description = "Caveman state dir (local-scan.json, sync.json, bin/).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64;
        message = "caveman module only packages linux_amd64 binaries; extend `plat` for other hosts.";
      }
    ];

    home.packages = [
      cavemanCli
      cavemanBinaries
    ];

    home.activation.cavemanDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${cfg.dataDir}"
      $DRY_RUN_CMD chmod 700 $VERBOSE_ARG "${cfg.dataDir}" 2>/dev/null || true
    '';
  };
}
