# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:
{
  imports = [
    ../../profiles/nixos/desktop.nix
    ../../modules/nixos/desktop/pipewire.nix
    ../../modules/nixos/hardware/nvidia.nix
    # Add ./hardware-configuration.nix after generating it on this host.
    ../../modules/nixos/programs/bash.nix
    ../../modules/nixos/programs/fish.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "studio";

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
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  security.sudo = {
    extraConfig = ''
      Defaults timestamp_timeout=1440
    '';
    extraRules = [
      {
        users = [ "wsl" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
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
  services.tailscale.extraUpFlags = [ "--accept-routes" ];

  services.flatpak.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # load `lib` into namespace at the file head with `{ config, pkgs, lib, ... }:`
  system.stateVersion = "26.05"; # Did you read the comment?
}
