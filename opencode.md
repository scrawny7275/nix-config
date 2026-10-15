# Nix / Home-Manager Conventions

This repository uses Nix flakes and home-manager modules.

## Language & Style

- Use `lib.mkMerge` and `lib.mkIf` for conditional config, not nested `if` expressions
- Prefer `lib.types` for option types; never use raw strings where a type exists
- Use `config.modules.user.ai...` for cross-module references, not hardcoded paths
- Keep `let` bindings minimal and close to their usage
- Avoid `with lib;` — use `lib.` prefix for explicitness
- Follow the existing module pattern: `{ config, pkgs, lib, ... }:` with `let...in` for locals

## Module Structure

- Shared modules imported via `imports = [ ../relative-path.nix ];`
- Secrets via `sops.secrets."api_keys/..."` with `mode = "0600"`
- Settings in `programs.&lt;name&gt;.settings` or `programs.&lt;name&gt;.{enable, ...}`
- Use absolute paths in Nix expressions where required

## Before Editing

1. Read the target file and its imports
2. Check sibling modules for existing patterns
3. Verify the change doesn't break `imports` chains

## After Editing

1. Run `nix flake check` to verify syntax and evaluation
2. For home-manager changes: validate with `home-manager switch --flake .#&lt;username&gt;` or equivalent dry-run
3. Do not commit unless explicitly asked

## Cross-Module References

- `config.modules.user.ai.omniroute` for OmniRoute settings
- `config.sops.secrets."api_keys/..."` for secret paths
