# modules/system/app/brave/default.nix
# Brave merges all .json files in the managed directory automatically.
{
  # Brave policies
  environment.etc."/brave/policies/managed/GroupPolicy.json".source = ./GroupPolicy.json;
  # User-Agent Switcher extension
  environment.etc."brave/policies/managed/extension-user-agent-switcher.json".source =
    ./user-agent-switcher.json;
}
