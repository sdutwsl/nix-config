{
  config,
  lib,
  inputs,
  ...
}:

{
  age.secrets.wg-bb-hk1-key = {
    file = inputs.privateConfig.lib.secretFile "wg-bb-hk1.key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.wireguard.interfaces.wg-bb-hk = {
    listenPort = 27960;
    privateKeyFile = config.age.secrets.wg-bb-hk1-key.path;
    mtu = 1420;

    ips = [
      "fd1d:2d70:1e77:ff01::1/64"
    ];

    allowedIPsAsRoutes = false;

    peers = [
      {
        publicKey = "oap/s/M6PtL81yaOl+dMIlE54dj9iQ3/NXWnG+e0Syk=";
        endpoint = "54.46.127.163:27960";

        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];

        persistentKeepalive = 25;
      }
    ];
  };

  networking.firewall.allowedUDPPorts = [ 27960 ];
  networking.firewall.interfaces.wg-bb-hk.allowedTCPPorts = [ 179 ];

  services.bird.config = lib.mkAfter (builtins.readFile ./bb-hk.conf);
}
