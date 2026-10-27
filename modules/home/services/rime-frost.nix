{ pkgs, ... }:
let
  updateRimeFrost = pkgs.writeShellScriptBin "update-rime-frost" ''
    export PATH=${pkgs.lib.makeBinPath [
      pkgs.coreutils
      pkgs.git
    ]}:$PATH

    ${builtins.readFile ../../../scripts/update_rime_frost.sh}
  '';
in
{
  home.packages = [
    updateRimeFrost
  ];

  systemd.user.services.update-rime-frost = {
    Unit = {
      Description = "Update rime-frost dictionary";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${updateRimeFrost}/bin/update-rime-frost";
      Restart = "on-failure";
      RestartSec = "15min";
    };
  };

  systemd.user.timers.update-rime-frost = {
    Unit = {
      Description = "Weekly rime-frost dictionary update";
    };

    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
      Unit = "update-rime-frost.service";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
