{ config, lib, pkgs, ... }:

let
  cfg = config.services.hysteria2Server;
  runtimeDirectory = "hysteria2-server";
  runtimePath = "/run/${runtimeDirectory}";

  baseConfig = pkgs.writeText "hysteria2-server-base.json" (builtins.toJSON {
    listen = ":${toString cfg.port}";

    tls = {
      cert = toString cfg.certificateFile;
      key = "${runtimePath}/server.key";
      sniGuard = "disable";
    };

    auth = {
      type = "password";
      password = "";
    };

    obfs = {
      type = "salamander";
      salamander.password = "";
    };

    masquerade = {
      type = "string";
      string = {
        content = "Not Found";
        headers.content-type = "text/plain; charset=utf-8";
        statusCode = 404;
      };
    };
  });

  prepareConfig = pkgs.writeShellScript "hysteria2-server-prepare-config" ''
    set -euo pipefail

    secret=${lib.escapeShellArg cfg.secretFile}
    runtime=${lib.escapeShellArg runtimePath}

    ${lib.getExe pkgs.jq} -e '
      type == "object"
      and (.authPassword | type == "string" and length > 0)
      and (.obfsPassword | type == "string" and length > 0)
      and (.tlsPrivateKey | type == "string" and length > 0)
    ' "$secret" >/dev/null

    ${lib.getExe pkgs.jq} -r '.tlsPrivateKey' "$secret" > "$runtime/server.key"
    ${pkgs.coreutils}/bin/chmod 0600 "$runtime/server.key"

    ${lib.getExe pkgs.jq} --slurpfile secret "$secret" '
      .auth.password = $secret[0].authPassword
      | .obfs.salamander.password = $secret[0].obfsPassword
    ' ${baseConfig} > "$runtime/config.json"
    ${pkgs.coreutils}/bin/chmod 0600 "$runtime/config.json"
  '';
in
{
  options.services.hysteria2Server = {
    enable = lib.mkEnableOption "Hysteria2 server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "UDP port used by the Hysteria2 server";
    };

    certificateFile = lib.mkOption {
      type = lib.types.path;
      description = "Public TLS certificate for the Hysteria2 server";
    };

    secretFile = lib.mkOption {
      type = lib.types.str;
      description = "JSON file containing authPassword, obfsPassword, and tlsPrivateKey";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the configured UDP port in the firewall";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.hysteria2 = { };
    users.users.hysteria2 = {
      isSystemUser = true;
      group = "hysteria2";
    };

    networking.firewall.allowedUDPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.hysteria2-server = {
      description = "Hysteria2 proxy server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "hysteria2";
        Group = "hysteria2";
        RuntimeDirectory = runtimeDirectory;
        RuntimeDirectoryMode = "0700";
        ExecStartPre = prepareConfig;
        ExecStart = "${lib.getExe pkgs.hysteria} server --disable-update-check --config ${runtimePath}/config.json";
        Restart = "on-failure";
        RestartSec = "5s";

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictSUIDSGID = true;
      };
    };
  };
}
