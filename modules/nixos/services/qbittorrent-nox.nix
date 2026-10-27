{ pkgs, ... }:
{
  systemd.services.qbittorrent-nox = {
    description = "qbittorrent-nox headless torrent client";
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
    };

    wantedBy = [ "multi-user.target" ];
  };
}
