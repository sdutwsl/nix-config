{
  config,
  lib,
  inputs,
  ...
}:

{
  age.secrets.wg-iedon-jp-key = {
    file = inputs.privateConfig.lib.secretFile "wg-iedon-jp.key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.firewall.allowedUDPPorts = [ 22796 ];
  networking.firewall.interfaces.wg-iedon-jp.allowedTCPPorts = [ 179 ];

  networking.wireguard.interfaces.wg-iedon-jp = {
    privateKeyFile = config.age.secrets.wg-iedon-jp-key.path;
    listenPort = 22796;
    allowedIPsAsRoutes = false;

    peers = [
      {
        publicKey = "XjKsLfOYJ8y/U9saLpfM/MjXErlQ7gkw3+OgQTdVZ0U=";
        endpoint = "jp-ty2.dn42.iedon.net:42506";
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

  services.bird.config = lib.mkAfter (builtins.readFile ./iedon-jp.conf);
}
