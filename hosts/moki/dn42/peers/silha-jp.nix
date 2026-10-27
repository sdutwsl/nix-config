{
  config,
  lib,
  inputs,
  ...
}:

{
  age.secrets.wg-silha-jp-key = {
    file = inputs.privateConfig.lib.secretFile "wg-silha-jp.key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.firewall.allowedUDPPorts = [ 20762 ];
  networking.firewall.interfaces.wg-silha-jp.allowedTCPPorts = [ 179 ];

  networking.wireguard.interfaces.wg-silha-jp = {
    privateKeyFile = config.age.secrets.wg-silha-jp-key.path;
    listenPort = 20762;
    allowedIPsAsRoutes = false;

    peers = [
      {
        publicKey = "ezOq3YaDR8wqJ8q42zq49YDBs8vC2mcDIxhJNvlpuE4=";
        endpoint = "az2.ymzymz.me:22796";
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        persistentKeepalive = 25;
      }
    ];

    ips = [ "fe80::2796/64" ];
    mtu = 1420;
  };

  services.bird.config = lib.mkAfter (builtins.readFile ./silha-jp.conf);
}
