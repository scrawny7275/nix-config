# modules/system/private.nix
# Adapter for the private flake input (system axis).
#
# Design:
# - The public repo ships a stub at share/private-stub (real = false).
# - The real environment lives in ~/nix-config-private (never published) and is
#   swapped in per-invocation with: --override-input private path:$HOME/nix-config-private
# - enable defaults to the input's `real` flag: strangers build with private
#   integration OFF; the owner builds with the override and gets it ON.
# - Explicitly enabling while the stub is active fails eval loudly (interlock).
# - When the private input ships its own policy.nix, it overrides the host's
#   public base policy (CA certs, noProxy domains).
{
  config,
  lib,
  inputs,
  ...
}:

let
  v = import (inputs.private + "/values.nix");
  privatePolicy = inputs.private + "/policy.nix";
  hasPrivatePolicy = v.real && builtins.pathExists privatePolicy;
  cfg = config.modules.private;
in
{
  options.modules.private = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = v.real;
      description = "Private environment integration (real values come from the private override input).";
    };

    values = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = v;
      description = "Values imported from the private input (stub or private override).";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> v.real;
          message = ''
            modules.private.enable is on, but the `private` input is the public stub.
            Rebuild with: --override-input private path:$HOME/nix-config-private
          '';
        }
      ];

      warnings = lib.optional (!v.real)
        "private input: public stub in effect (private override not supplied); private integration is disabled";
    }

    # Private policy (CA certs, noProxy domains) overrides the host's public
    # base policy when present. mkForce: hosts set policyFile with plain priority.
    (lib.mkIf hasPrivatePolicy {
      security.certificates.policyFile = lib.mkForce privatePolicy;
    })
  ];
}
