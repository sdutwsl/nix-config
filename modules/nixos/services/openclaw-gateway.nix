{ inputs, ... }:

{
  users.users.wsl.linger = true;

  age.secrets.openclaw-token = {
    file = inputs.privateConfig.lib.secretFile "openclaw-token";
    path = "/run/agenix/openclaw-token";
    owner = "wsl";
    group = "users";
    mode = "0400";
  };

  age.secrets.deepseek-api-key = {
    file = inputs.privateConfig.lib.secretFile "deepseek-api-key";
    path = "/run/agenix/deepseek-api-key";
    owner = "wsl";
    group = "users";
    mode = "0400";
  };

  age.secrets.telegram-bot-token = {
    file = inputs.privateConfig.lib.secretFile "telegram-bot-token";
    path = "/run/agenix/telegram-bot-token";
    owner = "wsl";
    group = "users";
    mode = "0400";
  };

  home-manager.users.wsl.imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
    ({ config, osConfig, pkgs, ... }: {
      programs.openclaw = {
        enable = true;

        bundledPlugins = {
          # Summarize web pages, PDFs, and YouTube videos.
          summarize.enable = true;

          # Search local Markdown notes and documentation.
          qmd.enable = true;
        };

        runtimePlugins = [
          # Render and inspect code changes as structured diffs.
          "diffs"

          # Model provider for agents.defaults.model (deepseek/...).
          "deepseek"

          # Provider for tools.web.search.
          "duckduckgo"
        ];

        systemd = {
          enable = true;
          unitName = "openclaw-gateway";
        };

        stateDir = "${config.home.homeDirectory}/.openclaw";

        config = {
          secrets.providers = {
            openclaw-token = {
              source = "file";
              path = osConfig.age.secrets.openclaw-token.path;
              mode = "singleValue";
            };

            deepseek-api-key = {
              source = "file";
              path = osConfig.age.secrets.deepseek-api-key.path;
              mode = "singleValue";
            };

            telegram-bot-token = {
              source = "file";
              path = osConfig.age.secrets.telegram-bot-token.path;
              mode = "singleValue";
            };
          };

          agents.defaults = {
            model.primary = "deepseek/deepseek-v4-pro";
            heartbeat.every = "0m";
            thinkingDefault = "off";
            compaction = {
              mode = "safeguard";
              midTurnPrecheck.enabled = true;
            };
          };

          commands.ownerAllowFrom = [
            "telegram:1383238887"
          ];

          models.providers.deepseek.apiKey = {
            source = "file";
            provider = "deepseek-api-key";
            id = "value";
          };

          models.providers.deepseek.models = [
            {
              id = "deepseek-v4-pro";
              name = "DeepSeek V4 Pro";
              contextTokens = 128000;
            }
          ];

          browser = {
            enabled = true;
            executablePath = "${pkgs.google-chrome}/bin/google-chrome-stable";
          };

          tools.loopDetection.enabled = true;

          tools.web.search = {
            enabled = true;
            provider = "duckduckgo";
          };

          channels.telegram = {
            enabled = true;
            dmPolicy = "pairing";
            # Pre-approved, so a fresh state needs no DM pairing.
            allowFrom = [
              "1383238887"
            ];
            execApprovals = {
              enabled = true;
              approvers = [
                "1383238887"
              ];
            };
            botToken = {
              source = "file";
              provider = "telegram-bot-token";
              id = "value";
            };
          };

          gateway = {
            mode = "local";
            bind = "lan";
            auth = {
              mode = "token";
              token = {
                source = "file";
                provider = "openclaw-token";
                id = "value";
              };
            };
          };
        };
      };

      systemd.user.services.openclaw-gateway.Install.WantedBy = [
        "default.target"
      ];
    })
  ];
}
