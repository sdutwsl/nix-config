# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      ../../profiles/nixos/desktop.nix
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/nixos/services/qbittorrent-nox.nix
      ../../modules/nixos/services/uptime-kuma.nix
      ../../modules/nixos/services/dae
      ../../modules/nixos/services/openclaw-gateway.nix
      ../../modules/nixos/services/local-mcp.nix
    ];
  dae.lanInterface = "enp3s0,docker0,virbr0";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    # if you use ipv4, this is all you need
    "net.ipv4.conf.all.forwarding" = true;
  };

  # Compressed in-RAM swap instead of a swapfile on the SSD.
  zramSwap.enable = true;
  boot.loader.systemd-boot.graceful = true;

  networking = {
    hostName = "aio"; # Define your hostname.
    # Pick only one of the below networking options.
    #  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    networkmanager.enable = false;  # Easiest to use and most distros use this by default.

    # Define VLANS

    # interfaces = {
    #   enp3s0 = {
    #     useDHCP = false;
    #     ipv4.addresses = [{
    #       address = "192.168.2.1";
    #       prefixLength = 24;
    #     }];
    #   };
    # };
    bridges.br-lan.interfaces = [ "enp3s0" ];
    interfaces.br-lan.ipv4.addresses = [
      {
        address = "192.168.2.1";
        prefixLength = 24;
      }
    ];
    interfaces.enp3s0.useDHCP = false;
    interfaces.enp1s0.useDHCP = true;


    bridges.br-vm.interfaces = [ ];
    interfaces.br-vm = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.3.1";
          prefixLength = 24;
        }
      ];
    };

    # nftables = {
    #   enable = true;
    #   ruleset = ''
    #     table ip nat {
    #       chain postrouting {
    #         type nat hook postrouting priority 100; policy accept;
    #         oifname "enp1s0" masquerade
    #       }
    #     }
    #   '';
    # };

    nat = {
      enable = true;
      externalInterface = "enp1s0";
      internalInterfaces = [ "br-lan" "br-vm" ];
    };
  };

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.flatpak.enable = true;
  

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wsl = {
     isNormalUser = true;
     extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  };

  # programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
   
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    exfatprogs
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    qbittorrent-nox
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "wsl";
  };


  services.kea = {
    dhcp4 = {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = [
            "br-lan"
            "br-vm"
          ];
        };
        lease-database = {
          name = "/var/lib/kea/dhcp4.leases";
          persist = true;
          type = "memfile";
        };
        renew-timer  = 1000;
        rebind-timer = 2000;
        valid-lifetime = 4000;
        subnet4 = [
          {
            id = 1;
            subnet = "192.168.2.0/24";
            pools = [
              { pool = "192.168.2.100 - 192.168.2.200"; }
            ];
            option-data = [
              { name = "routers"; data = "192.168.2.1"; }
              { name = "domain-name-servers"; data = "8.8.8.8,114.114.114.114"; }
            ];
          }
          {
            id = 2;
            subnet = "192.168.3.0/24";
            pools = [
              { pool = "192.168.3.100 - 192.168.3.200"; }
            ];
            option-data = [
              { name = "routers"; data = "192.168.3.1"; }
              { name = "domain-name-servers"; data = "8.8.8.8,114.114.114.114"; }
            ];
          }
        ];
      };
    };
  };
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "smbnix";
        "netbios name" = "smbnix";
        "security" = "user";
        "hosts allow" = "0.0.0.0/0";
      };      
      "c" = {
        "path" = "/sdcard/windows";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "wsl";
        "force group" = "wheel";
        "valid users" = "wsl";
      };
      "d" = {
        "path" = "/sdcard/d";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "wsl";
        "force group" = "wheel";
        "valid users" = "wsl";
      };
      "e" = {
        "path" = "/sdcard/e";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "wsl";
        "force group" = "wheel";
        "valid users" = "wsl";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };



  # tailscale
  services.tailscale.enable = true;
 
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  virtualisation.docker.enable = true;
#  virtualisation.docker.rootless = {
#    enable = true;
#    setSocketVariable = true;
#  };

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  # virtualisation.waydroid.enable = true;

  users.extraGroups.docker.members = [ "wsl" ];


  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .

  # nix.settings.substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
  system.stateVersion = "26.05"; # Did you read the comment?

}
