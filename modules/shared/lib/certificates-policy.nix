# modules/shared/lib/certificates-policy.nix
{ config, lib }:

let
  cfg = config.security.certificates;
  fleetDefaults = import ../policy/certificates.nix;
  hostPolicy = if cfg.policyFile != null then import cfg.policyFile else { };
in
fleetDefaults
// hostPolicy
// {
  # Host CAS completely override fleet CAS. If you want merging instead,
  # change this to: fleetDefaults.cas // hostPolicy.cas or {}
  cas = hostPolicy.cas or fleetDefaults.cas;
}
