{
  config,
  lib,
  inputs,
  ...
}:

{
  age.secrets.wg-bakapub-jp-key = {
    file = inputs.privateConfig.lib.secretFile "wg-bakapub-jp.key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.firewall.allowedUDPPorts = [ 23374 ];
  networking.firewall.interfaces.wg-bakapub-jp.allowedTCPPorts = [ 179 ];

  networking.wireguard.interfaces.wg-bakapub-jp = {
    privateKeyFile = config.age.secrets.wg-bakapub-jp-key.path;
    listenPort = 23374;
    allowedIPsAsRoutes = false;

    peers = [
      {
        publicKey = "N7iQzqWLPb6lpRlf7grQG6rEzQOvDZWkmsRDkRnniH0=";
        endpoint = "jp01.dn42.baka.pub:22796";
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

  services.bird.config = lib.mkAfter (builtins.readFile ./bakapub-jp.conf);
}
