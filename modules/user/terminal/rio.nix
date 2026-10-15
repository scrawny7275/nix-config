# modules/user/terminal/rio.nix
# Hardware-accelerated GPU terminal emulator powered by WebGPU
{ pkgs, ... }:

{
  programs.rio = {
    enable = true;
    settings = {
      window = {
        opacity = 0.80;
        blur = true;

      };
      padding-x = 20; # Left and right padding
      padding-y = [
        10
        10
      ]; # Top and bottom padding

      navigation = {
        mode = "BottomTab";
        use-current-path = true;
      };

      # CORRECT: Shell is a table, not a string
      shell = {
        program = "${pkgs.fish}/bin/fish";
        args = [ "--login" ];
      };
    };
  };
}
