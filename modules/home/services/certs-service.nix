{
  config,
  lib,
  pkgs,
  ...
}:

let
  certDir = "${config.home.homeDirectory}/certs";
  stateDir = "${config.xdg.stateHome}/personal-certificates";
  webroot = "${config.xdg.dataHome}/personal-nginx/acme";
  certificates = {
    personal-nginx = {
      domain = "www.sdutwsl.cn";
      action = "reload";
    };
    derper = {
      domain = "derper.sdutwsl.cn";
      action = "restart";
    };
    status = {
      domain = "status.sdutwsl.cn";
      action = "reload";
      service = "personal-nginx";
    };
    resume = {
      domain = "resume.sdutwsl.cn";
      action = "reload";
      service = "personal-nginx";
    };
    mcp = {
      domain = "mcp.sdutwsl.cn";
      action = "reload";
      service = "personal-nginx";
    };
  };
  renew =
    name: certificate:
    pkgs.writeShellApplication {
      name = "renew-${name}-certificate";
      runtimeInputs = [
        pkgs.certbot
        pkgs.coreutils
        pkgs.systemd
        pkgs.util-linux
      ];
      text = ''
        install -d -m 700 ${lib.escapeShellArg certDir}
        exec 9>${lib.escapeShellArg "${certDir}/.renew.lock"}
        flock --wait 540 9
        certbot certonly --non-interactive --agree-tos \
          --register-unsafely-without-email \
          --server https://acme-v02.api.letsencrypt.org/directory \
          --webroot --webroot-path ${lib.escapeShellArg webroot} \
          --config-dir ${lib.escapeShellArg certDir} \
          --work-dir ${lib.escapeShellArg "${certDir}/work"} \
          --logs-dir ${lib.escapeShellArg "${certDir}/logs"} \
          --cert-name ${certificate.domain} \
          --domain ${certificate.domain} \
          --keep-until-expiring

        install -d -m 700 ${lib.escapeShellArg stateDir}
        fingerprint=$(sha256sum \
          ${lib.escapeShellArg "${certDir}/live/${certificate.domain}/fullchain.pem"} \
          ${lib.escapeShellArg "${certDir}/live/${certificate.domain}/privkey.pem"})
        previous=$(cat ${lib.escapeShellArg "${stateDir}/${name}.sha256"} 2>/dev/null || true)
        if [ "$fingerprint" != "$previous" ] || ! systemctl --user is-active --quiet ${certificate.service or name}.service; then
          systemctl --user ${certificate.action} ${certificate.service or name}.service
          printf '%s\n' "$fingerprint" > ${lib.escapeShellArg "${stateDir}/${name}.sha256"}
        fi
      '';
    };
in
{
  systemd.user.services = lib.mapAttrs' (
    name: certificate:
    lib.nameValuePair "${name}-certificate" {
      Unit = {
        Description = "Obtain or renew ${certificate.domain} certificate";
        Requires = [ "personal-nginx.service" ];
        After = [ "personal-nginx.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${renew name certificate}/bin/renew-${name}-certificate";
        UMask = "0077";
        TimeoutStartSec = "20min";
      };
    }
  ) certificates;

  systemd.user.timers = lib.mapAttrs' (
    name: certificate:
    lib.nameValuePair "${name}-certificate" {
      Unit.Description = "Check ${certificate.domain} certificate twice daily";
      Timer = {
        OnBootSec = "2min";
        OnCalendar = "*-*-* 00,12:00:00";
        RandomizedDelaySec = "15min";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    }
  ) certificates;
}
