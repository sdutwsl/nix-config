{ lib, pkgs, singBoxUpdateSubscription, ... }:
{
  systemd.services.sing-box = {
    serviceConfig.ExecStartPre = lib.mkForce "+${singBoxUpdateSubscription}";
  };

  systemd.services.sing-box-update-subscription = {
    description = "Update sing-box subscription";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = singBoxUpdateSubscription;
      ExecStartPost = "${pkgs.systemd}/bin/systemctl reload-or-restart sing-box.service";
    };
  };

  systemd.timers.sing-box-update-subscription = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };
}
