# modules/user/shell/zsh/p10k.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zsh-powerlevel10k
  ];

  # Use home.file to manage the Powerlevel10k configuration file (~/.p10k.zsh)
  # This ensures the prompt is configured as defined here, preventing the wizard from running again.

  # Use home.file to manage the Powerlevel10k configuration file (~/.p10k.zsh)
  # This ensures the prompt is configured as defined in the inlined text,
  # preventing the wizard from running again.
  # NOTE: Literal single quotes (') within the Zsh script content have been
  #       escaped as ('') for inclusion within the Nix multiline string ('' ... '').
  # Use home.file to manage the Powerlevel10k configuration file (~/.p10k.zsh)
  # This ensures the prompt is configured as defined in the sourced file,
  # preventing the wizard from running again.
  # The 'source' attribute reads the file content directly from your Nix config repo,
  # avoiding potential string escaping issues within the Nix expression.
  home.file.".p10k.zsh".source = ./.p10k.zsh; # Path relative to this .nix file
}
