# modules/user/ai/opencode/secrets.nix
{ config, ... }:
{
  sops.secrets = {
    "api_keys/opencode_zen".mode = "0600";
    "api_keys/kimi".mode = "0600";
    "api_keys/gemini".mode = "0600";
    "api_keys/omnirouter".mode = "0600";
    "api_keys/openrouter".mode = "0600";
    "api_keys/freellmapi_encryption".mode = "0600";
    "api_keys/freellmapi_unified".mode = "0600";
    "api_keys/pollinations".mode = "0600";
    "api_keys/aihubmix".mode = "0600";
    "api_keys/claude_platform".mode = "0600";
    "api_keys/openai_platform".mode = "0600";
    "api_keys/nvidia".mode = "0600";
    "api_keys/cloudfare".mode = "0600";
    "cloudfare/account_id".mode = "0600";
    "api_keys/huggingface".mode = "0600";
    "api_keys/sambanova".mode = "0600";
    "api_keys/anytype".mode = "0600"; # local API key for the anytype CLI client (modules/user/ai/anytype.nix)
    # "api_keys/experientiallabs".mode = "0600"; # TODO: key lost from yaml; re-mint at platform.experientiallabs.ai and re-add
  };
}
