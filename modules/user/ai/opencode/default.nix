# modules/user/ai/opencode/default.nix
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  omni = config.modules.user.ai.omniroute;
  sm = config.modules.user.ai.supermemory;
in
{
  imports = [
    ../omniroute.nix
    ../freellmapi.nix
    ../supermemory.nix
    ./secrets.nix
    ./lsp.nix
    ./provider-health.nix
  ];

  programs.opencode = {
    enable = true;
    package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    web.enable = false;

    settings = {
      # default: nvidia/z-ai/glm-5.3 (2026-10-16; USER DECISION — kimi-k3 reached
      # end of life on NVIDIA Build 2026-10-15, hard HTTP 410, verified in
      # provider-health state.csv). GLM tool-calls verified live in narrow probes
      # (TTFB 1.6–13.1s on 2026-10-16, far better than the historical 57–84s).
      # Fallback if it degrades: opencode/mimo-v2.6-flash-free.
      model = "nvidia/z-ai/glm-5.3";
      default_agent = "plan";
      # TODO: enable this within is on module, with an enable and enable opencode integration options.
      plugin = [
        "context-mode"
      ]
      ++ lib.optionals (sm.enable && sm.mode != "off") [ "opencode-supermemory@2.0.15" ];
      provider = import ./providers.nix { inherit config; };

      # Enforcement hardening (approved 2026-09-30, "full stack"; amended
      # 2026-10-05 after the internal review — scoped private-repo exception):
      # deny writes outside the session working dir; bash funnel guards for
      # known scatter paths, the Anytype API loopback, git remote mutations
      # (each push / merge asks), settings bypasses (--no-verify, hooksPath),
      # and plaintext-secret materialization to stdout (sops decrypt asks).
      permission = {
        external_directory = {
          # order-sensitive: generic rule first, scoped exceptions after.
          # 2026-10-05 backfire fix: wildcard was "deny" which hard-blocked
          # verification READS of deployed home state (~/.local/share,
          # ~/.nix-profile) mid-task; for a dotfiles-admin workflow the trust
          # domain is the machine, not the cwd. Softened to "ask" per sparring
          # verdict (flip back on rubber-stamp/approved-stray/noise-breach).
          "*" = "ask";
          # Private companion repo: eval-time values, never pushed.
          # Home-derived so the repo path doesn't pin a local username.
          "${config.home.homeDirectory}/nix-config-private/**" = "allow";
        };
        bash = {
          "*" = "allow";
          "cat*>>*~/.local/bin/*" = "deny";
          "*>*/.local/bin/*" = "deny";
          "curl*127.0.0.1:31009*" = "deny";
          # Remote-mutating git ops require in-session approval.
          "git push*" = "ask";
          "git push" = "ask";
          # Commit is the ship moment: the user holds the gate. Mechanical
          # backstop for the four-questions skill's self-answers (2026-10-21
          # sparring verdict).
          "git commit*" = "ask";
          "git commit" = "ask";
          "gh pr merge*" = "ask";
          "gh repo delete*" = "deny";
          # Hook bypasses are never allowed from agent sessions.
          "git*--no-verify*" = "deny";
          "git*-c core.hooksPath*" = "deny";
          # Plaintext secrets to stdout must be a conscious user decision.
          "sops decrypt*" = "ask";
          "sops -d*" = "ask";
          "sops --decrypt*" = "ask";
          "cat*age/keys.txt*" = "deny";
          "age -d*" = "deny";
          "age --decrypt*" = "deny";
          # The compositional class (pipes/fallbacks yielding plaintext) is
          # covered data-side by plugins/secret-redact.ts, not pattern-globs.
        };
      };
    };

    tui = {
      theme = "system";
    };

    context = ./AGENTS.md;
    agents = ./agents;

    lsp = {
      enable = true;
      languages = [
        "nix"
        "go"
        "python"
        "typescript"
        "rust"
        "astro"
        "bash"
        "yaml"
        "eslint"
        "fish"
        "dockerfile"
        "html"
        "css"
        "json"
        "scala"
      ];
    };

    extraPackages = [ pkgs.python3 ]; # python3: context-mode sandbox runtime (ctx_execute language: "python")
  };

    # Skills (vendored obra/superpowers subset); opencode auto-discovers
    # ~/.config/opencode/skills/<name>/SKILL.md. The HM module has no
    # programs.opencode.skills option, hence xdg.configFile.
    xdg.configFile."opencode/skills".source = ./skills;

    # Output firewall plugin — auto-loaded from ~/.config/opencode/plugins/ at
    # startup. Redacts secret-shaped content from tool outputs (data-side; see
    # incident notes in ADR form within the plugin file header).
    xdg.configFile."opencode/plugins/secret-redact.ts".source = ./plugins/secret-redact.ts;

  home.packages = [ inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop ];
  modules.user.ai.omniroute.enable = true;
  modules.user.ai.freellmapi.enable = true;
  modules.user.ai.supermemory.enable = true;
  modules.user.ai.opencode.providerHealth.enable = true;
}
