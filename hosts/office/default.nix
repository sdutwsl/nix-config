# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config
, pkgs
, lib
, inputs
, ...
}:
{
  imports = [
    ../../profiles/nixos/desktop.nix
    ../../modules/nixos/desktop/pipewire.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/nixos/programs/bash.nix
    ../../modules/nixos/programs/fish.nix
    ../../modules/nixos/services/dae
    ../../modules/nixos/services/local-mcp.nix
  ];
  dae.lanInterface = "enp2s0,docker0,virbr0,tailscale0,wlp0s20f0u4";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Fail fast when a USB device does not answer its initial descriptor request.
  # This avoids long root-hub stalls without depending on a physical USB port.
  boot.kernelParams = [
    "usbcore.old_scheme_first=0"
    "usbcore.initial_descriptor_timeout=100"
    "usbcore.use_both_schemes=0"
  ];
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=CN
  '';

  networking.hostName = "office"; # Define your hostname.

  security.pki.certificateFiles = [
    ../../cert/mkcert-rootCA.pem
    ../../cert/AppleIncRootCertificate.pem
    ../../cert/AppleRootCA-G2.pem
    ../../cert/AppleRootCA-G3.pem
  ];
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "172.16.26.116,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  programs.muralop.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  # services.displayManager.sddm.wayland.enable = true;
  # services.displayManager.sddm.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];

  # enable Sway window manager
  #  programs.sway = {
  #    enable = true;
  #    wrapperFeatures.gtk = true;
  #  };

  services.vscode-server.enable = true;
  services.usbmuxd.enable = true;
  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  security.sudo.extraConfig = "Defaults timestamp_timeout=1440";
  # programs.adb.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wsl = {
    isNormalUser = true;
    description = "wsl";
    extraGroups = [
      "networkmanager"
      "wheel"
      "adbusers"
      "docker"
      "libvirtd"
      "input"
      "kvm"
      "video"
      "render"
    ];
    packages = with pkgs; [ ];
  };

  age.secrets.local-mcp-tunnel.file = inputs.privateConfig.lib.secretFile "local-mcp-tunnel";

  # mcp.sdutwsl.moe -> local-mcp on this host via Cloudflare Tunnel "local-mcp"
  services.cloudflared = {
    enable = true;
    tunnels."f70186d0-babc-4df2-85d9-fb989bda27cb" = {
      credentialsFile = config.age.secrets.local-mcp-tunnel.path;
      ingress."mcp.sdutwsl.moe" = "http://localhost:18765";
      default = "http_status:404";
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    idevicerestore
    libimobiledevice
    usbutils
    libirecovery
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  security.polkit.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # programs.clash-verge = {
  #   enable = true;
  #  autoStart = true;
  # };

  # programs.niri.enable = true;

  #virtualisation.virtualbox.host.enable = true;
  #users.extraGroups.vboxusers.members = [ "wsl" ];
  #virtualisation.virtualbox.host.enableExtensionPack = true;
  #virtualisation.virtualbox.guest.enable = true;
  #virtualisation.virtualbox.guest.x11 = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  # virtualisation.waydroid.enable = true;
  virtualisation.docker.enable = true;
  #  virtualisation.docker.rootless = {
  #    enable = true;
  #    setSocketVariable = true;
  #  };
  users.extraGroups.docker.members = [ "wsl" ];

  # List services that you want to enable:
  # tailscale
  services.tailscale.enable = true;
  services.tailscale.extraUpFlags = [
    "--advertise-exit-node"
    "--accept-routes"
  ];

  services.flatpak.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    8080
    8081
  ];
  networking.firewall.allowedUDPPorts = [
    59010
    59011
  ];

  networking.firewall.interfaces.wlp0s20f0u4.allowedUDPPorts = [
    53
    67
  ];
  networking.firewall.interfaces.wlp0s20f0u4.allowedTCPPorts = [ 53 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  # networking.proxy.default = "http://172.16.26.116:7890/";
  # networking.proxy.noProxy = "172.16.26.116,localhost,internal.domain";
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # load `lib` into namespace at the file head with `{ config, pkgs, lib, ... }:`
  system.stateVersion = "26.05"; # Did you read the comment?
}
