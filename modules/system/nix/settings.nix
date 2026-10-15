{
  nix.settings = {
    keep-outputs = true; # Keep build outputs (prevents re-downloading/rebuilding)
    keep-derivations = true; # Keep derivations (the build recipes)
    # Enable the Flakes feature and the accompanying new nix command-line tool
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
