{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ../../profiles/nixos/server.nix
    ../../modules/nixos/services/hysteria2-server.nix
    ./dn42
    ./hardware-configuration.nix
  ];

  age.secrets.moki-hysteria2-server = {
    file = inputs.privateConfig.lib.secretFile "moki-hysteria2-server";
    owner = "hysteria2";
    group = "hysteria2";
    mode = "0400";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  swapDevices = [
    { device = "/swapfile"; size = 2048; }
  ];

  networking.hostName = "moki";
  networking.networkmanager.enable = true;
  networking.useDHCP = false;

  time.timeZone = "Asia/Tokyo";

  users.users.wsl = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIF2rblhsgR1sd6vphIjdq2jhS021ZX3k5GJw6+aDhxZ wsl@nixos"
    ];
  };

  security.sudo.wheelNeedsPassword = true;
  security.sudo.extraRules = [
    {
      users = [ "wsl" ];
      runAs = "root";
      commands = lib.concatMap
        (unit: lib.concatMap
          (action: map
            (systemctl: {
              command = "${systemctl} ${action} ${unit}";
              options = [ "NOPASSWD" "NOSETENV" ];
            })
            [ "${pkgs.systemd}/bin/systemctl" "/run/current-system/sw/bin/systemctl" ])
          [ "start" "stop" "restart" ])
        [
          "bird.service"
          "hysteria2-server.service"
          "dn42-roa-update.service"
          "dn42-roa-update.timer"
          "network-addresses-lo.service"
          "wireguard-wg-iedon-jp.service"
          "wireguard-wg-iedon-jp.target"
          "wireguard-wg-silha-jp.service"
          "wireguard-wg-silha-jp.target"
          "wireguard-wg-bakapub-jp.service"
          "wireguard-wg-bakapub-jp.target"
          "wireguard-wg-bb-hk.service"
          "wireguard-wg-bb-hk.target"
        ]
        ++ map
          (command: {
            inherit command;
            options = [ "NOPASSWD" "NOSETENV" ];
          })
          [
            "${config.services.bird.package}/bin/birdc"
            "/run/current-system/sw/bin/birdc"
            "${pkgs.wireguard-tools}/bin/wg"
            "/run/current-system/sw/bin/wg"
            "/etc/profiles/per-user/wsl/bin/wg"
          ];
    }
  ];

  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  services.hysteria2Server = {
    enable = true;
    certificateFile = ../../cert/moki-hysteria2.pem;
    secretFile = config.age.secrets.moki-hysteria2-server.path;
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    bird2
  ];

  system.stateVersion = "26.05";
}
