# modules/user/desktop/mako.nix
# Lightweight Wayland notification daemon

let
  theme = import ./theme.nix;
in
{
  services.mako = {
    enable = false;
    settings = {
      anchor = "top-center";
      background-color = theme.bg-transparent;
      border-color = theme.bg-transparent;
      text-color = theme.text;
      border-radius = 8;
      default-timeout = 10000;
      font = "monospace 10";
      height = 150;
      icons = true;
      layer = "overlay";
      margin = 10;
      markup = true;
      width = 300;
    };

    extraConfig = ''
      [mode=do-not-disturb]
      invisible=1
    '';
  };
}
