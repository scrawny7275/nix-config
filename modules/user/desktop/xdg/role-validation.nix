# modules/user/desktop/xdg/role-validation.nix
# Pure post-merge validation for the closed role-candidate registry.
# Unit-tested in tests/default.nix; wired into config.assertions by
# modules/user/desktop/xdg/default.nix. Option types cannot read merged
# config, so the "unregistered selection fails at eval" gate lives here
# as assertions — the NixOS-idiomatic mechanism for cross-option checks.
{ lib }:

{
  # roleApps          : { role -> selected desktop ID }         (merged)
  # roleCandidates    : { role -> [ registered desktop IDs ] } (merged)
  # mimeTypeOverrides : { mime -> ID | [ID] }                   (merged)
  # → [ error message ] ([] = valid)
  #
  # Three gates:
  #   1. every roleApps selection ∈ its roleCandidates (the typo /
  #      unregistered-app class — the historical org.system76.* bug);
  #   2. every roleCandidates key is a known role (registration typos);
  #   3. every mimeTypeOverrides value ∈ the union of all known IDs
  #      (same typo class on the escape hatch).
  roleSelectionErrors =
    roleApps: roleCandidates: mimeTypeOverrides:
    let
      roles = lib.naturalSort (builtins.attrNames roleApps);
      fmt = v: lib.concatStringsSep ", " (lib.naturalSort v);

      selectionErrors = map
        (
          r: "xdg.roleApps.${r}: \"${roleApps.${r}}\" is not a registered candidate (registered for ${r}: ${fmt (roleCandidates.${r} or [ ])}). Register it in modules.user.desktop.xdg.roleCandidates.${r} or fix the desktop ID."
        )
        (lib.filter (r: !lib.elem roleApps.${r} (roleCandidates.${r} or [ ])) roles);

      registrationErrors = map
        (r: "xdg.roleCandidates.\"${r}\" is not a known role (known roles: ${fmt roles}).")
        (
          lib.filter (r: !lib.elem r roles)
            (builtins.attrNames roleCandidates)
        );

      knownIds = lib.unique (
        builtins.attrValues roleApps
        ++ lib.concatLists (builtins.attrValues roleCandidates)
      );

      overrideErrors = map
        (
          m: "xdg.mimeTypeOverrides.\"${m}\": references unregistered desktop ID(s) (known IDs: ${fmt knownIds}). Register the app as a candidate for some role, or fix the ID."
        )
        (
          lib.filter
            (m: !lib.all (id: lib.elem id knownIds) (lib.toList mimeTypeOverrides.${m}))
            (builtins.attrNames mimeTypeOverrides)
        );
    in
    selectionErrors ++ registrationErrors ++ overrideErrors;
}
