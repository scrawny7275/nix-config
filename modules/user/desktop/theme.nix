# modules/user/desktop/theme.nix
let
  # Define colors as variables first (in scope for inherit)
  bg = "#16171A";
  accent = "#7fc8ff";
  text = "#EEFFFF";
  black = "#000000";

  # Derived variants
  bg-transparent = "#16171ACC";
  bg-90 = "#16171AE6";
  accent-transparent = "#7fc8ff80";
  accent-50 = "#7fc8ff80";
  text-15 = "#FFFFFF26";
  shadow = "#00000066";
in
{
  # Export all colors for direct access (theme.bg, theme.accent, etc.)
  inherit
    bg
    accent
    text
    black
    bg-transparent
    bg-90
    accent-transparent
    accent-50
    text-15
    shadow
    ;

  # Substitution function
  substitute =
    file:
    let
      colors = {
        inherit
          bg
          accent
          text
          black
          bg-transparent
          bg-90
          accent-transparent
          accent-50
          text-15
          shadow
          ;
      };
      names = builtins.attrNames colors;
      fromList = map (name: "@${name}") names;
      toList = builtins.attrValues colors;
    in
    builtins.replaceStrings fromList toList (builtins.readFile file);
}
