{ pkgs, ... }:

{
  imports = [
    ./roa.nix
    # DN42
    ./peers/bakapub-jp.nix
    ./peers/iedon-jp.nix
    ./peers/silha-jp.nix
    # Backbone
    ./peers/bb-hk1.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
  };
  networking.firewall.checkReversePath = "loose";
  networking.interfaces.lo = {
    ipv4.addresses = [
      {
        address = "172.21.92.33";
        prefixLength = 32;
      }
    ];
    ipv6.addresses = [
      {
        address = "fd1d:2d70:1e77::1";
        prefixLength = 128;
      }
    ];
  };

  systemd.services.bird = {
    requires = [ "network-addresses-lo.service" ];
    after = [ "network-addresses-lo.service" ];
  };

  services.bird = {
    enable = true;
    package = pkgs.bird2;
    config = builtins.concatStringsSep "\n" [
      (builtins.readFile ./bird/common.conf)
      (builtins.readFile ./bird/role-exit.conf)
      (builtins.readFile ./bird/host.conf)
    ];
    checkConfig = false;
  };
}
