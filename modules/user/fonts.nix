# modules/user/fonts.nix
{ lib, pkgs, ... }:

{
  # Ensure icon fonts are available to all apps (including sandboxed ones like Helium)
  home.packages = with pkgs; [
    # Common font families
    dejavu_fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji

    # Terminus font (bitmap console font, also usable in X11 terminals)
    terminus_font

    nerd-fonts._0xproto
    nerd-fonts.droid-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.ubuntu-mono
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.code-new-roman # Nerd Fonts: Tunable, slashed zeros, compact smaller characters
    nerd-fonts.meslo-lg # Nerd Fonts: Slashed zeros, customized version of Apple's Menlo
    font-awesome # Font Awesome - OTF font
    roboto
    noto-fonts-lgc-plus # Beautiful and free fonts for many languages
    noto-fonts-cjk-sans # Beautiful and free fonts for CJK languages
    noto-fonts-cjk-serif # Beautiful and free fonts for CJK languages
    noto-fonts-emoji-blob-bin # Noto Emoji with extended Blob support
    noto-fonts-monochrome-emoji # Monochrome emoji font
    liberation_ttf # Liberation Fonts, replacements for Times New Roman, Arial, and Courier New
    dejavu_fonts # Typeface family based on the Bitstream Vera fonts
  ];

  fonts.fontconfig.enable = true;

  # Optional: enforce fallback in GTK/Qt apps
  xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>Symbols Nerd Font</family>
          <family>Noto Color Emoji</family>
        </prefer>
      </alias>
    </fontconfig>
  '';

  home.activation.fontsCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Rebuilding font cache..."
    ${pkgs.fontconfig}/bin/fc-cache -f -v >/dev/null 2>&1 || true
  '';
}
