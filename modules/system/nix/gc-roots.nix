# modules/system/nix/gc-roots.nix
{ inputs, ... }:

{
  system.activationScripts.pin-flake-inputs = ''
    mkdir -p /nix/var/nix/gcroots/flake-inputs
    # Pin flake input Git repos (evaluation-time dependencies)
    # Only inputs from systemInputs (flake.nix) are available here
    ln -sfn ${inputs.stable.outPath} /nix/var/nix/gcroots/flake-inputs/nixpkgs-stable
    ln -sfn ${inputs.unstable.outPath} /nix/var/nix/gcroots/flake-inputs/nixpkgs-unstable
    ln -sfn ${inputs.sops-nix.outPath} /nix/var/nix/gcroots/flake-inputs/sops-nix
    ln -sfn ${inputs.nixos-cosmic.outPath} /nix/var/nix/gcroots/flake-inputs/nixos-cosmic
  '';
}
