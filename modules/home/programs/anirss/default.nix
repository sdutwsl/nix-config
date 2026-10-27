{
  config,
  pkgs,
  lib,
  ...
}:

let
  stateDir = "${config.home.homeDirectory}/.local/state/ani-rss";
  jarUrl = "https://github.com/wushuo894/ani-rss/releases/latest/download/ani-rss.jar";

  aniRssPrepare = pkgs.writeShellApplication {
    name = "ani-rss-prepare";

    runtimeInputs = with pkgs; [
      curl
      coreutils
    ];

    text = ''
      set -euo pipefail

      mkdir -p "${stateDir}"

      tmp="${stateDir}/ani-rss.jar.tmp"
      jar="${stateDir}/ani-rss.jar"

      echo "Downloading latest ani-rss.jar..."

      curl -fL \
        -A "ani-rss-systemd-service" \
        "${jarUrl}" \
        -o "$tmp"

      chmod 0644 "$tmp"
      mv "$tmp" "$jar"

      echo "ani-rss.jar updated."
    '';
  };
in
{
  home.packages = [
    aniRssPrepare
  ];

  systemd.user.services.ani-rss = {
    Unit = {
      Description = "ani-rss";
      After = [ "network.target" ];
    };

    Service = {
      ExecStartPre = "${lib.getExe aniRssPrepare}";

      ExecStart = ''
        ${pkgs.bash}/bin/bash -lc 'cd ${lib.escapeShellArg stateDir} && exec ${pkgs.jdk25}/bin/java -jar ${lib.escapeShellArg "${stateDir}/ani-rss.jar"}'
      '';

      Environment = [ "MCP_ENABLED=true" ];

      Restart = "on-failure";
      RestartSec = "10s";

      NoNewPrivileges = true;
      PrivateTmp = true;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
