# modules/user/desktop/niri/hm-to-kdl.nix
#
# Converts Home Manager-style niri window/layer rule attrsets into KDL nodes.
# This allows app modules to declare rules in a format-agnostic way while
# the niri module handles the translation to KDL when useKdlConfig = true.
{ inputs, lib }:

let
  inherit (inputs.niri.lib.kdl) plain leaf;

  matchToKdl =
    match:
    leaf "match" (
      { }
      // (lib.optionalAttrs (match ? app-id) { inherit (match) app-id; })
      // (lib.optionalAttrs (match ? title) { inherit (match) title; })
      // (lib.optionalAttrs (match ? namespace) { inherit (match) namespace; })
    );

  convertWindowRule =
    rule:
    let
      matchNodes = lib.optionals (rule ? matches) (map matchToKdl rule.matches);

      propertyNodes =
        (lib.optionals (rule ? open-floating) [ (leaf "open-floating" rule.open-floating) ])
        ++ (lib.optionals (rule ? open-on-workspace) [
          (leaf "open-on-workspace" rule.open-on-workspace)
        ])
        ++ (lib.optionals (rule ? geometry-corner-radius) [
          (
            let
              r = rule.geometry-corner-radius;
            in
            if builtins.isInt r then
              leaf "geometry-corner-radius" r
            else
              leaf "geometry-corner-radius" {
                inherit (r)
                  top-left
                  top-right
                  bottom-left
                  bottom-right
                  ;
              }
          )
        ])
        ++ (lib.optionals (rule ? clip-to-geometry) [ (leaf "clip-to-geometry" rule.clip-to-geometry) ])
        ++ (lib.optionals (rule ? tiled-state) [ (leaf "tiled-state" rule.tiled-state) ])
        ++ (lib.optionals (rule ? focus-ring) [ (plain "focus-ring" (convertStyleAttrs rule.focus-ring)) ])
        ++ (lib.optionals (rule ? border) [
          (
            let
              b = rule.border;
            in
            if builtins.isBool b then
              leaf "border" (if b then "on" else "off")
            else
              plain "border" (convertStyleAttrs b)
          )
        ])
        ++ (lib.optionals (rule ? block-out-from) [ (leaf "block-out-from" rule.block-out-from) ])
        ++ (lib.optionals (rule ? background-effect) [
          (plain "background-effect" [ (leaf "blur" rule.background-effect.blur) ])
        ]);
    in
    plain "window-rule" (matchNodes ++ propertyNodes);

  convertLayerRule =
    rule:
    let
      matchNodes = lib.optionals (rule ? matches) (map matchToKdl rule.matches);

      propertyNodes = lib.optionals (rule ? place-within-backdrop) [
        (leaf "place-within-backdrop" rule.place-within-backdrop)
      ];
    in
    plain "layer-rule" (matchNodes ++ propertyNodes);

  convertStyleAttrs =
    style:
    (lib.optionals (style ? color) [ (leaf "color" style.color) ])
    ++ (lib.optionals (style ? width) [ (leaf "width" style.width) ])
    ++ (lib.optionals (style ? active-color) [ (leaf "active-color" style.active-color) ])
    ++ (lib.optionals (style ? inactive-color) [ (leaf "inactive-color" style.inactive-color) ])
    ++ (lib.optionals (style ? border-radius) [ (leaf "border-radius" style.border-radius) ]);

in
{
  windowRulesToKdl = rules: map convertWindowRule rules;
  layerRulesToKdl = rules: map convertLayerRule rules;
}
