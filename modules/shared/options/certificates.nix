# modules/shared/options/certificates.nix
{ lib, ... }:

{
  options.security.certificates = {
    enable = lib.mkEnableOption "custom CA certificates" // {
      default = true;
    };

    policyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a host-specific policy file (pure attrset).
        Defines which CAs exist, their paths, and global settings.
      '';
    };
  };
}
