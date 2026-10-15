// modules/user/ai/opencode/plugins/secret-redact.ts
//
// Output firewall for agent tool calls. Runs on every tool.execute.after and
// rewrites secret-shaped material in the output BEFORE it can persist to
// transcripts, session storage, indexes, or provider context.
//
// Design contract (per the incident review):
// - Data-first: matches secret SHAPES (not command strings), because permission
//   rules cannot see what a compound command yields.
// - Generic classes ONLY. Repo-specific token content never ships here — the
//   pre-push token sweep in the private companion repo owns that list.
// - Narrow class coverage beats broad entropy heuristics: one false-positive
//   per ten thousand outputs; every rule here is prefix/signature-pinned.
// - On any match: the value is replaced by [REDACTED:<class>] so a downstream
//   reader/tool (and the human) sees that something was redacted; never partial
//   leakage.
//
// Deployed to ~/.config/opencode/plugins/secret-redact.ts via home-manager
// (see default.nix). Auto-loaded at session start by opencode.

import type { Plugin } from "@opencode-ai/plugin";

const RULES: Array<[RegExp, string]> = [
  // Key containers first (whole-block redaction, multi-line)
  [
    /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP |ENCRYPTED )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA |PGP |ENCRYPTED )?PRIVATE KEY-----/g,
    "pem-private-key",
  ],
  [
    /-----BEGIN OpenVPN Static key V1-----[\s\S]*?-----END OpenVPN Static key V1-----/g,
    "openvpn-tls-crypt",
  ],
  // age secret keys
  [/\bAGE-SECRET-KEY-1[A-Z0-9]{40,}\b/g, "age-secret-key"],
  // GitHub token formats
  [/\bgithub_pat_[A-Za-z0-9_]{20,}\b/g, "github-pat"],
  [/\bgh[pousr]_[A-Za-zA-Z0-9]{30,}\b/g, "github-token"],
  [/\bglpat-[A-Za-z0-9_-]{10,}\b/g, "gitlab-pat"],
  // OpenAI/OpenRouter/Anthropic-style keys
  [/\bsk-(?:ant-|proj-|or-v1-)?[A-Za-z0-9_.-]{20,}\b/g, "sk-token"],
  // HF / NVIDIA / Cloudflare user tokens
  [/\bhf_[A-Za-z0-9]{20,}\b/g, "huggingface-token"],
  [/\bnvapi-[A-Za-z0-9_-]{20,}\b/g, "nvidia-api-key"],
  [/\bcfut_[A-Za-z0-9_-]{20,}\b/g, "cloudflare-user-token"],
  [/\bfreellmapi-[a-z0-9-]{15,}\b/g, "freellmapi-key"],
  // supermemory / misc vendored prefixes
  [/\bsm_[A-Za-z0-9_-]{20,}\b/g, "supermemory-token"],
  // JWTs
  [/\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}\b/g, "jwt"],
  // AWS access key ids
  [/\bAKIA[0-9A-Z]{12,}\b/g, "aws-access-key"],
  // Slack tokens
  [/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/g, "slack-token"],
];

export const SecretRedact: Plugin = async () => {
  return {
    "tool.execute.after": async (_input, output) => {
      if (typeof output.output !== "string" || output.output.length === 0) return;
      let text = output.output;
      let hits = 0;
      const classes = new Set<string>();
      for (const [re, cls] of RULES) {
        text = text.replace(re, () => {
          hits++;
          classes.add(cls);
          return `[REDACTED:${cls}]`;
        });
      }
      if (hits === 0) return;
      output.output = text;
      const note = `[secret-redact plugin: suppressed ${hits} match(es) — ${[...classes].join(",")}]`;
      output.title = output.title ? `${output.title} ${note}` : note;
    },
  };
};

export default SecretRedact;
