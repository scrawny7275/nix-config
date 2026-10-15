# modules/user/desktop/qt.nix
{ pkgs, ... }:

{
  qt = {
    enable = true;

    # Use KDE/Plasma platform theme for native file dialogs and settings
    platformTheme.name = "qtct"; # kde

    # Use Breeze style (light/dark follows KDE settings or can be set via kvantum)
    style.name = "breeze";

    # Kvantum for advanced theming (optional but recommended for dark theme control)
    kvantum = {
      enable = true;
      settings = {
        General = {
          theme = "KvArcDark"; # or "KvGnomeDark", "KvYaruDark", "KvAdaptaDark"
        };
      };
      themes = [
        pkgs.arc-kde-theme # provides KvArcDark / KvArc
      ];
    };

    # KDE settings via kwriteconfig6 for dark mode and other preferences
    kde.settings = {
      kcmfonts = {
        General = {
          font = "Noto Sans,10,-1,5,50,0,0,0,0,0";
          menuFont = "Noto Sans,10,-1,5,50,0,0,0,0,0";
          toolBarFont = "Noto Sans,10,-1,5,50,0,0,0,0,0";
        };
      };
      kdeglobals = {
        General = {
          # Accent color (Breeze blue)
          AccentColor = "61,174,233";
          # Dark color scheme
          ColorScheme = "BreezeDark";
          # Default applications style
          widgetStyle = "Breeze";
        };
        Icons = {
          Theme = "Yaru-dark";
        };
      };
    };

    qt5ctSettings = {
      Appearance = {
        style = "Breeze";
        icon_theme = "Yaru-dark";
      };
    };
    qt6ctSettings = {
      Appearance = {
        style = "Breeze";
        icon_theme = "Yaru-dark";
      };
    };
  };
}
