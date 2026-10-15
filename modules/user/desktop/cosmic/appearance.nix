# modules/user/desktop/cosmic/appearance.nix
{ cosmicLib, ... }:

let
  inherit (cosmicLib.cosmic) mkRON;

  # Import your centralized theme
  theme = import ../theme.nix;

  # Convert #RRGGBB hex → { red, green, blue } floats (0.0–1.0)
  hexToFloats =
    hex:
    let
      clean = builtins.substring 1 (builtins.stringLength hex - 1) hex;
      hexToInt =
        h:
        let
          digits = {
            "0" = 0;
            "1" = 1;
            "2" = 2;
            "3" = 3;
            "4" = 4;
            "5" = 5;
            "6" = 6;
            "7" = 7;
            "8" = 8;
            "9" = 9;
            "a" = 10;
            "b" = 11;
            "c" = 12;
            "d" = 13;
            "e" = 14;
            "f" = 15;
            "A" = 10;
            "B" = 11;
            "C" = 12;
            "D" = 13;
            "E" = 14;
            "F" = 15;
          };
          val = i: builtins.getAttr (builtins.substring i 1 h) digits;
        in
        (val 0) * 16 + (val 1);
      r = hexToInt (builtins.substring 0 2 clean);
      g = hexToInt (builtins.substring 2 2 clean);
      b = hexToInt (builtins.substring 4 2 clean);

      # Emit raw RON float strings to avoid lib.strings.floatToString warnings
      mkFloat = n: mkRON "raw" (builtins.toString (n / 255.0));
    in
    {
      red = mkFloat r;
      green = mkFloat g;
      blue = mkFloat b;
    };

  accentRGB = hexToFloats theme.accent; # #7fc8ff
  bgRGB = hexToFloats theme.bg; # #16171A
  textRGB = hexToFloats theme.text; # #EEFFFF

in
{
  theme = {
    mode = "dark";

    dark = {
      bg_color = mkRON "optional" {
        red = bgRGB.red;
        green = bgRGB.green;
        blue = bgRGB.blue;
        alpha = 0.75; # 25% transparent
      };

      primary_container_bg = mkRON "optional" {
        red = bgRGB.red;
        green = bgRGB.green;
        blue = bgRGB.blue;
        alpha = 0.65; # Cards/dialogs slightly more transparent
      };

      secondary_container_bg = mkRON "optional" {
        red = bgRGB.red;
        green = bgRGB.green;
        blue = bgRGB.blue;
        alpha = 0.55; # Secondary panels most transparent
      };

      # ── Future blur flag  ──
      is_frosted = true;

      # ── Your accent color everywhere ──
      accent = mkRON "optional" {
        red = accentRGB.red;
        green = accentRGB.green;
        blue = accentRGB.blue;
      };

      window_hint = mkRON "optional" {
        red = accentRGB.red;
        green = accentRGB.green;
        blue = accentRGB.blue;
      };

      active_hint = 1;
      gaps = mkRON "tuple" [
        0
        8
      ];

      # ── Default COSMIC corner radii ──
      corner_radii = {
        radius_0 = mkRON "tuple" [
          0.0
          0.0
          0.0
          0.0
        ];
        radius_xs = mkRON "tuple" [
          4.0
          4.0
          4.0
          4.0
        ];
        radius_s = mkRON "tuple" [
          8.0
          8.0
          8.0
          8.0
        ];
        radius_m = mkRON "tuple" [
          16.0
          16.0
          16.0
          16.0
        ];
        radius_l = mkRON "tuple" [
          32.0
          32.0
          32.0
          32.0
        ];
        radius_xl = mkRON "tuple" [
          160.0
          160.0
          160.0
          160.0
        ];
      };

      # ── Tints derived from your theme ──
      neutral_tint = mkRON "optional" {
        red = bgRGB.red;
        green = bgRGB.green;
        blue = bgRGB.blue;
      };

      text_tint = mkRON "optional" {
        red = textRGB.red;
        green = textRGB.green;
        blue = textRGB.blue;
      };

      # ── Semantic colors ──
      success = mkRON "optional" {
        red = 0.2;
        green = 0.8;
        blue = 0.4;
      };

      destructive = mkRON "optional" {
        red = 1.0;
        green = 0.3;
        blue = 0.3;
      };

      warning = mkRON "optional" {
        red = 1.0;
        green = 0.7;
        blue = 0.2;
      };

      # ── Default COSMIC palette BUT with your accent replacing blue ──
      palette = {
        __type = "enum";
        variant = "Dark";
        value = [
          {
            name = "custom-dark";

            neutral_0 = {
              red = 0.0;
              green = 0.0;
              blue = 0.0;
              alpha = 1.0;
            };
            neutral_1 = {
              red = 0.1;
              green = 0.1;
              blue = 0.1;
              alpha = 1.0;
            };
            neutral_2 = {
              red = 0.2;
              green = 0.2;
              blue = 0.2;
              alpha = 1.0;
            };
            neutral_3 = {
              red = 0.3;
              green = 0.3;
              blue = 0.3;
              alpha = 1.0;
            };
            neutral_4 = {
              red = 0.4;
              green = 0.4;
              blue = 0.4;
              alpha = 1.0;
            };
            neutral_5 = {
              red = 0.5;
              green = 0.5;
              blue = 0.5;
              alpha = 1.0;
            };
            neutral_6 = {
              red = 0.6;
              green = 0.6;
              blue = 0.6;
              alpha = 1.0;
            };
            neutral_7 = {
              red = 0.7;
              green = 0.7;
              blue = 0.7;
              alpha = 1.0;
            };
            neutral_8 = {
              red = 0.8;
              green = 0.8;
              blue = 0.8;
              alpha = 1.0;
            };
            neutral_9 = {
              red = 0.9;
              green = 0.9;
              blue = 0.9;
              alpha = 1.0;
            };
            neutral_10 = {
              red = 1.0;
              green = 1.0;
              blue = 1.0;
              alpha = 1.0;
            };

            gray_1 = {
              red = 0.1;
              green = 0.1;
              blue = 0.1;
              alpha = 1.0;
            };
            gray_2 = {
              red = 0.2;
              green = 0.2;
              blue = 0.2;
              alpha = 1.0;
            };

            # YOUR ACCENT (#7fc8ff) replacing the default blue
            accent_blue = {
              red = accentRGB.red;
              green = accentRGB.green;
              blue = accentRGB.blue;
              alpha = 1.0;
            };
            accent_indigo = {
              red = 0.35;
              green = 0.35;
              blue = 0.95;
              alpha = 1.0;
            };
            accent_purple = {
              red = 0.60;
              green = 0.30;
              blue = 0.90;
              alpha = 1.0;
            };
            accent_pink = {
              red = 0.95;
              green = 0.30;
              blue = 0.65;
              alpha = 1.0;
            };
            accent_red = {
              red = 0.95;
              green = 0.25;
              blue = 0.30;
              alpha = 1.0;
            };
            accent_orange = {
              red = 0.95;
              green = 0.55;
              blue = 0.20;
              alpha = 1.0;
            };
            accent_yellow = {
              red = 0.95;
              green = 0.80;
              blue = 0.20;
              alpha = 1.0;
            };
            accent_green = {
              red = 0.25;
              green = 0.80;
              blue = 0.45;
              alpha = 1.0;
            };
            accent_warm_grey = {
              red = 0.55;
              green = 0.50;
              blue = 0.48;
              alpha = 1.0;
            };

            # Extended palette also uses your accent for blue tones
            ext_blue = {
              red = accentRGB.red;
              green = accentRGB.green;
              blue = accentRGB.blue;
              alpha = 1.0;
            };
            ext_indigo = {
              red = 0.45;
              green = 0.40;
              blue = 0.95;
              alpha = 1.0;
            };
            ext_purple = {
              red = 0.65;
              green = 0.35;
              blue = 0.90;
              alpha = 1.0;
            };
            ext_pink = {
              red = 0.90;
              green = 0.35;
              blue = 0.60;
              alpha = 1.0;
            };
            ext_red = {
              red = 0.90;
              green = 0.30;
              blue = 0.35;
              alpha = 1.0;
            };
            ext_orange = {
              red = 0.90;
              green = 0.50;
              blue = 0.25;
              alpha = 1.0;
            };
            ext_yellow = {
              red = 0.90;
              green = 0.75;
              blue = 0.25;
              alpha = 1.0;
            };
            ext_warm_grey = {
              red = 0.50;
              green = 0.47;
              blue = 0.45;
              alpha = 1.0;
            };

            bright_green = {
              red = 0.30;
              green = 0.90;
              blue = 0.50;
              alpha = 1.0;
            };
            bright_orange = {
              red = 0.95;
              green = 0.55;
              blue = 0.25;
              alpha = 1.0;
            };
            bright_red = {
              red = 0.95;
              green = 0.30;
              blue = 0.35;
              alpha = 1.0;
            };
          }
        ];
      };

      spacing = {
        space_none = 0;
        space_xxxs = 4;
        space_xxs = 8;
        space_xs = 12;
        space_s = 16;
        space_m = 24;
        space_l = 32;
        space_xl = 48;
        space_xxl = 64;
        space_xxxl = 128;
      };
    };
  };

  toolkit = {
    apply_theme_global = false;
    icon_theme = "Cosmic";
    header_size = mkRON "enum" "Standard";
    interface_density = mkRON "enum" "Standard";
    show_minimize = false;
    show_maximize = false;
  };
}
