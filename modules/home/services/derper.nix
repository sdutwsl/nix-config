{
  config,
  lib,
  pkgs,
  ...
}:

let
  domain = "derper.sdutwsl.cn";
  certDir = "${config.home.homeDirectory}/certs/live/${domain}";
  stateDir = "${config.xdg.dataHome}/derper";
  derperCertDir = "${stateDir}/certs";
  derper = "${pkgs.tailscale.derper}/bin/derper";
  prepare = pkgs.writeShellApplication {
    name = "prepare-derper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.tailscale
      pkgs.jq
    ];
    text = ''
      install -d -m 700 ${lib.escapeShellArg stateDir} ${lib.escapeShellArg derperCertDir}
      test -s ${certDir}/fullchain.pem
      test -s ${certDir}/privkey.pem
      ln -sf ${certDir}/fullchain.pem ${derperCertDir}/${domain}.crt
      ln -sf ${certDir}/privkey.pem ${derperCertDir}/${domain}.key
      timeout 15 tailscale status --json | jq -e '.BackendState == "Running"' >/dev/null
    '';
  };
in
{
  home.packages = [ pkgs.tailscale ];

  systemd.user.services.derper = {
    Unit = {
      Description = "Tailscale DERP server";
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStartPre = "${prepare}/bin/prepare-derper";
      ExecStart = ''
        ${derper} \
          -c ${stateDir}/derper.key \
          --certmode=manual \
          --certdir=${derperCertDir} \
          --hostname=${domain} \
          -a :7006 \
          -stun-port 7007 \
          -http-port 7008 \
          --verify-clients
      '';
      Restart = "always";
      RestartSec = "30s";
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
