# modules/user/app/brave/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  mergeScript = pkgs.runCommand "brave-merge-prefs.sh" { } ''
    cp ${./merge-prefs.sh} $out
    chmod +x $out
  '';

in
{
  programs.brave = {
    enable = true;

    # Proxy toggle via command line args
    commandLineArgs = [
      (if config.proxy.enable && config.proxy.http != null
       then "--proxy-server=${config.proxy.http}"
       else "--no-proxy-server")
    ];

    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden Password Manager
      { id = "bhchdcejhohfmigjafbampogmaanbfkg"; } # User-Agent Switcher and Manager
    ];

    # Spell check dictionaries
    dictionaries = with pkgs; [ hunspellDictsChromium.en_US ];
  };

  # For check if specific setting was applay it use:
  # jq '.brave.new_tab_page.show_stats' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
  home.activation.mergeBraveSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${mergeScript} ${pkgs.jq}/bin/jq '${./Preferences.json}' '${config.home.homeDirectory}/.config/BraveSoftware/Brave-Browser/Default/Preferences'
  '';
}
