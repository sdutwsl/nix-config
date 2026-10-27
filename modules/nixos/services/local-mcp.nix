{ config, pkgs, inputs, ... }:
let
  local-mcp = pkgs.python3Packages.buildPythonApplication {
    pname = "local-mcp";
    version = "0.1.0";
    pyproject = true;
    src = inputs.local-mcp;
    build-system = [ pkgs.python3Packages.hatchling ];
    dependencies = [ pkgs.python3Packages.mcp ];
  };
  # Public URL is the OAuth issuer, so each host advertises the domain that reaches it.
  publicUrl = {
    office = "https://mcp.sdutwsl.moe";
    aio = "https://mcp.sdutwsl.cn";
  }.${config.networking.hostName};
in
{
  age.secrets.local-mcp-token.file = inputs.privateConfig.lib.secretFile "local-mcp-token";

  # Streamable HTTP: http://<host>:18765/mcp, SSE: http://<host>:18765/sse
  # Listens on all interfaces so ali-server can reach aio over Tailscale (mcp.sdutwsl.cn).
  systemd.services.local-mcp = {
    description = "local-mcp MCP server";
    after = [ "network.target" ];
    # run_shell uses `bash -l`, which loads the full NixOS PATH from /etc/profile.
    path = [ pkgs.bash ];

    serviceConfig = {
      ExecStart = "${local-mcp}/bin/local-mcp --host 0.0.0.0 --port 18765 --token-file %d/token --public-url ${publicUrl} --enable-shell";
      LoadCredential = "token:${config.age.secrets.local-mcp-token.path}";
      # run_shell executes commands as wsl, so the service runs as wsl too.
      User = "wsl";
      Group = "users";
      # OAuth clients and tokens survive restarts (STATE_DIRECTORY).
      StateDirectory = "local-mcp";
      # The state dir was created under DynamicUser; systemd keeps the old owner, so fix it as root.
      ExecStartPre = "+${pkgs.coreutils}/bin/chown -R wsl:users /var/lib/local-mcp";
      Restart = "on-failure";
    };

    wantedBy = [ "multi-user.target" ];
  };
}
