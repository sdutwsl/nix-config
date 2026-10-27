{ pkgs, ... }:

{
  systemd.services.dn42-roa-update = {
    description = "Update DN42 ROA tables";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "bird.service" ];
    path = [ pkgs.curl pkgs.coreutils pkgs.systemd pkgs.bird2 ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0755 /etc/bird
      if curl --fail --silent --show-error --location --connect-timeout 15 --max-time 60 \
          https://dn42.burble.com/roa/dn42_roa_bird2_4.conf -o /etc/bird/roa_dn42.conf.new \
        && curl --fail --silent --show-error --location --connect-timeout 15 --max-time 60 \
          https://dn42.burble.com/roa/dn42_roa_bird2_6.conf -o /etc/bird/roa_dn42_v6.conf.new; then
        mv /etc/bird/roa_dn42.conf.new /etc/bird/roa_dn42.conf
        mv /etc/bird/roa_dn42_v6.conf.new /etc/bird/roa_dn42_v6.conf
        chmod 0644 /etc/bird/roa_dn42.conf /etc/bird/roa_dn42_v6.conf
        if systemctl --quiet is-active bird.service; then
          birdc configure
          birdc reload in all
        fi
      else
        rm -f /etc/bird/roa_dn42.conf.new /etc/bird/roa_dn42_v6.conf.new
        test -s /etc/bird/roa_dn42.conf
        test -s /etc/bird/roa_dn42_v6.conf
      fi
    '';
  };

  systemd.services.bird = {
    requires = [ "dn42-roa-update.service" ];
    after = [ "dn42-roa-update.service" ];
  };

  systemd.timers.dn42-roa-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
    };
  };
}
