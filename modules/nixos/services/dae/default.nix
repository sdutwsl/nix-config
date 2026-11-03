{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.dae;
  directProcesses = lib.concatStringsSep ", " cfg.directProcesses;
in
{
  options.dae = {
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "LAN interfaces for DAE transparent proxy bypass";
    };

    upstream = lib.mkOption {
      type = lib.types.str;
      default = "socks5://127.0.0.1:7891";
      description = "Upstream proxy for DAE";
    };

    directProcesses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "sing-box" ];
      description = "Process names that should bypass DAE";
    };
  };

  config = {
    services.dae = {
      enable = true;
      assets = with pkgs; [
        v2ray-geoip
        v2ray-domain-list-community
      ];
      config = builtins.replaceStrings
        [
          "  lan_interface: enp2s0,docker0,virbr0,tailscale0,wlan0"
          "  proxy: 'socks5://127.0.0.1:7891'"
          "  pname(proxy-process) -> must_direct"
        ]
        [
          "  lan_interface: ${cfg.lanInterface}"
          "  proxy: '${cfg.upstream}'"
          "  pname(${directProcesses}) -> must_direct"
        ]
        (builtins.readFile ./dotfiles/dae.dae);
    };
  };
}
