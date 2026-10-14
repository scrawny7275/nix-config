# modules/user/app/gpui-shell/default.nix
{ inputs, pkgs, ... }:

let
  # Color palette extracted from Ironbar CSS theme
  colors = {
    # Background colors
    bg-primary = "#16171A";
    bg-secondary = "#3D3E42";
    bg-tertiary = "#2D3035";
    bg-elevated = "#45484D";

    # Text colors
    text-primary = "#cdd6f4";
    text-secondary = "#AFDABC";
    text-muted = "#7B9984";
    text-disabled = "#5A6B72";
    text-placeholder = "#5A6B72";

    # Border colors
    border-default = "#7B9984";
    border-subtle = "#3D3E42";
    border-focused = "#7fc8ff";

    # Accent colors
    accent-primary = "#7fc8ff";
    accent-selection = "#1C3943";
    accent-hover = "#5BA489";

    # Status colors
    status-success = "#70C68A";
    status-warning = "#FBBF24";
    status-error = "#1C3943";
    status-info = "#46A44D";

    # Interactive colors
    interactive-default = "#3D3E42";
    interactive-hover = "#505C61";
    interactive-active = "#2A6657";
    interactive-toggle-on = "#7fc8ff";
    interactive-toggle-on-hover = "#5BA489";
  };
in
{
  home.packages = [ inputs.shell.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  xdg.configFile."gpuishell/config.toml".text = ''
    [bar]
    size = 32.0
    position = "top"
    start = []
    center = ["Clock", "Workspaces", "Settings"]
    end = []

    [launcher]
    width = 600.0
    height = 450.0
    margin_top = 100.0
    margin_right = 0.0
    margin_bottom = 0.0
    margin_left = 10.0

    [osd]
    position = "bottom"

    [control_center.power_actions]
    sleep = "systemctl suspend"
    reboot = "systemctl reboot"
    poweroff = "systemctl poweroff"

    [font]
    family = "JetBrainsMono Nerd Font"
    size_base = 13.0
  '';

  xdg.configFile."gpuishell/theme.toml".text = ''
    # GPUi Shell Theme
    # Color palette: Catppuccin-inspired with custom green accents

    [bg]
    primary = "${colors.bg-primary}"
    secondary = "${colors.bg-secondary}"
    tertiary = "${colors.bg-tertiary}"
    elevated = "${colors.bg-elevated}"

    [text]
    primary = "${colors.text-primary}"
    secondary = "${colors.text-secondary}"
    muted = "${colors.text-muted}"
    disabled = "${colors.text-disabled}"
    placeholder = "${colors.text-placeholder}"

    [border]
    default = "${colors.border-default}"
    subtle = "${colors.border-subtle}"
    focused = "${colors.border-focused}"

    [accent]
    primary = "${colors.accent-primary}"
    selection = "${colors.accent-selection}"
    hover = "${colors.accent-hover}"

    [status]
    success = "${colors.status-success}"
    warning = "${colors.status-warning}"
    error = "${colors.status-error}"
    info = "${colors.status-info}"

    [interactive]
    default = "${colors.interactive-default}"
    hover = "${colors.interactive-hover}"
    active = "${colors.interactive-active}"
    toggle_on = "${colors.interactive-toggle-on}"
    toggle_on_hover = "${colors.interactive-toggle-on-hover}"

    font_size_base = 13.0
  '';
}
