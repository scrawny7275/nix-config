# modules/user/desktop/hyprsunset.nix
{
  services.hyprsunset = {
    enable = true;
    extraArgs = [
      "-t"
      "4000" # temperature
      "-d"
      "6500" # daytime temp
      "-l"
      "52.5" # latitude
      "-L"
      "13.4" # longitude
    ];
  };
}
