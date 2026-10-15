# modules/user/ai/anytype.nix
# Thin read-anywhere + sandbox-only-write CLI client for the Anytype Local API.
# Trial spec: modules/user/ai/anytype-trial.md
{
  config,
  pkgs,
  ...
}:

{
  # Secret declared alongside the other opencode-attached api keys.
  sops.secrets."api_keys/anytype".mode = "0600";

  # Rendered at activation so the key never lands in the nix store.
  sops.templates."anytype-api-key" = {
    path = "${config.xdg.configHome}/anytype-agent/api-key";
    mode = "0400";
    content = config.sops.placeholder."api_keys/anytype";
  };

  # Sandbox space: AgentLab, id taken from /v2/auth/whoami grant on 2026-10-02
  # (id changed after the 0.56.1→0.57.3 app switch + key re-issue; space ids are
  # device/install-derived, the earlier d4gzh… id died with the old generation).
  home.sessionVariables.ANYTYPE_SANDBOX_ID = "bafyreihsetx4aya3fwvjvw3lvhroe4p5yjfaknaq76zeivdtk3ofdlfy44.392c4s40nba6c";

  home.packages = [
    (pkgs.writeShellScriptBin "anytype-cli" (builtins.readFile ./anytype.sh))
  ];
}
