# modules/user/ai/opencode/providers.nix
{ config, ... }:

let
  omni = config.modules.user.ai.omniroute;
  secretFile = path: "{file:${config.sops.secrets.${path}.path}}";
in
{
  omniroute = {
    npm = "@ai-sdk/openai-compatible";
    name = "OmniRoute";
    # disabled-in-practice (2026-09-26): OmniRoute's auto pool had zero working
    # upstreams (oc/* keyless stub 403s through proxies by design). Re-enable only
    # if quota-separation routing through OmniRoute returns — see omniroute.nix note.
    options = {
      baseURL = "http://127.0.0.1:${toString omni.port}/v1";
      apiKey = omni.apiKey;
    };
    models.auto.name = "Auto";
  };

  opencode = {
    npm = "@ai-sdk/openai-compatible";
    name = "OpenCode Zen";
    options = {
      baseURL = "https://opencode.ai/zen/v1";
      apiKey = secretFile "api_keys/opencode_zen";
    };
  };

  google = {
    npm = "@ai-sdk/google";
    name = "Google";
    options.apiKey = secretFile "api_keys/gemini";
  };

  nvidia = {
    npm = "@ai-sdk/openai-compatible";
    name = "NVIDIA Build";
    options = {
      baseURL = "https://integrate.api.nvidia.com/v1";
      apiKey = secretFile "api_keys/nvidia";
    };
    models = {
      "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning" = {
        name = "Nemotron 3 Nano Omni 30B A3B Reasoning";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-3-super-120b-a12b" = {
        name = "Nemotron 3 Super 120B A12B";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-3-ultra-550b-a55b" = {
        name = "Nemotron 3 Ultra 550B A55B";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-3.5-lightning-30b-a3b" = {
        name = "Nemotron 3.5 Lightning 30B A3B";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-nano-3-30b-a3b" = {
        name = "Nemotron Nano 3 30B A3B";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/llama-3.1-nemotron-ultra-253b-v1" = {
        name = "Llama 3.1 Nemotron Ultra 253B V1";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/llama-3.1-nemotron-70b-instruct" = {
        name = "Llama 3.1 Nemotron 70B Instruct";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/llama-3.1-nemotron-51b-instruct" = {
        name = "Llama 3.1 Nemotron 51B Instruct";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/mistral-nemo-minitron-8b-8k-instruct" = {
        name = "Mistral Nemo Minitron 8B 8K Instruct";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "z-ai/glm-5.3" = {
        name = "GLM 5.3";
        cost = {
          input = 0;
          output = 0;
        };
      };
    };
  };

  openrouter = {
    npm = "@ai-sdk/openai-compatible";
    name = "OpenRouter";
    options = {
      baseURL = "https://openrouter.ai/api/v1";
      apiKey = secretFile "api_keys/openrouter";
    };
    models = {
      "deepseek/deepseek-v4-flash-0731:free" = {
        name = "DeepSeek V4 Flash 0731 Free";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free" = {
        name = "Nemotron 3 Nano Omni 30B A3B Reasoning Free";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-3-super-120b-a12b:free" = {
        name = "Nemotron 3 Super 120B A12B Free";
        cost = {
          input = 0;
          output = 0;
        };
      };
      "nvidia/nemotron-3-ultra-550b-a55b:free" = {
        name = "Nemotron 3 Ultra 550B A55B Free";
        cost = {
          input = 0;
          output = 0;
        };
      };
    };
  };

  freellmapi = {
    npm = "@ai-sdk/openai-compatible";
    name = "FreeLLMAPI";
    options = {
      baseURL = "http://127.0.0.1:3001/v1";
      apiKey = secretFile "api_keys/freellmapi_unified";
    };
    models = {
      "auto".name = "Auto";
    };
  };

  sambanova = {
    npm = "@ai-sdk/openai-compatible";
    name = "SambaNova";
    options = {
      baseURL = "https://api.sambanova.ai/v1";
      apiKey = secretFile "api_keys/sambanova";
    };
    models = {
      "DeepSeek-V3.1" = {
        name = "DeepSeek V3.1";
        cost = { input = 0; output = 0; };
      };
      "Meta-Llama-3.3-70B-Instruct" = {
        name = "Llama 3.3 70B";
        cost = { input = 0; output = 0; };
      };
      "gpt-oss-120b" = {
        name = "GPT-OSS 120B";
        cost = { input = 0; output = 0; };
      };
    };
  };

  cloudflare = {
    npm = "@ai-sdk/openai-compatible";
    name = "Cloudflare Workers AI";
    options = {
      baseURL = "https://api.cloudflare.com/client/v4/accounts/${secretFile "cloudfare/account_id"}/ai/v1";
      apiKey = secretFile "api_keys/cloudfare";
    };
    models = {
      "@cf/meta/llama-3.3-70b-instruct-fp8-fast" = {
        name = "Llama 3.3 70B";
        cost = { input = 0; output = 0; };
      };
      "@cf/openai/gpt-oss-120b" = {
        name = "GPT-OSS 120B";
        cost = { input = 0; output = 0; };
      };
      "@cf/qwen/qwen2.5-coder-32b-instruct" = {
        name = "Qwen2.5 Coder 32B";
        cost = { input = 0; output = 0; };
      };
    };
  };

  huggingface = {
    npm = "@ai-sdk/openai-compatible";
    name = "Hugging Face";
    options = {
      baseURL = "https://router.huggingface.co/v1";
      apiKey = secretFile "api_keys/huggingface";
    };
    models = {
      "deepseek-ai/DeepSeek-V3-0324" = {
        name = "DeepSeek V3";
        cost = { input = 0; output = 0; };
      };
      "openai/gpt-oss-120b" = {
        name = "GPT-OSS 120B";
        cost = { input = 0; output = 0; };
      };
      "meta-llama/Llama-3.3-70B-Instruct" = {
        name = "Llama 3.3 70B";
        cost = { input = 0; output = 0; };
      };
    };
  };

}
