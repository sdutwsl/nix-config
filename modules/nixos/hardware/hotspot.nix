{ config, inputs, ... }:
{
  age.secrets.nixwifi-psk = {
    file = inputs.privateConfig.lib.secretFile "nixwifi-psk";
    path = "/run/agenix/nixwifi-psk";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.networkmanager.ensureProfiles.environmentFiles = [
    config.age.secrets.nixwifi-psk.path
  ];

  networking.networkmanager.ensureProfiles.profiles.NixWiFi = {
    connection = {
      id = "NixWiFi";
      type = "wifi";
      interface-name = "wlp0s20f0u4";
      autoconnect = "true";
      autoconnect-priority = "100";
    };
    wifi = {
      mode = "ap";
      ssid = "NixWiFi";
      band = "a";
      channel = "36";
      channel-width = "80";
      cloned-mac-address = "permanent";
      powersave = "2";
    };
    wifi-security = {
      key-mgmt = "wpa-psk";
      psk = "$NIXWIFI_PSK";
      proto = "rsn";
      pairwise = "ccmp";
      group = "ccmp";
    };
    ipv4.method = "shared";
    ipv6.method = "ignore";
  };
}
