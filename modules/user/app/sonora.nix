# modules/user/app/sonora.nix
{
  inputs,
  ...
}:

{
  imports = [ inputs.sonora.homeManagerModules.sonora ];

  programs.sonora = {
    enable = true;
    settings = {
      provider = "youtube";
      appearance.theme = "dark";
    };
  };
}
