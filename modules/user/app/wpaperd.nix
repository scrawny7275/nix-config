{
  services.wpaperd = {
    enable = false;
    settings = {
      any = {
        path = "~/Pictures/wall/desktop/nix-d-nord-blue.png";
        mode = "center";
      };
    };
  };

  home.sessionVariables = {
    RUST_BACKTRACE = "full";
    COLORBT_SHOW_HIDDEN = 1;
  };
}
