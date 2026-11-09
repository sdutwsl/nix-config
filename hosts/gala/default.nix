{ pkgs, ... }:
{
  imports = [
    # Fonts (CJK), fcitx5 (mozc + chinese-addons), Steam, zh_CN/ja_JP locales, flakes.
    ../../profiles/nixos/desktop.nix
    ../../modules/nixos/desktop/pipewire.nix
    ../../modules/nixos/programs/sogoupinyin.nix
    ../../modules/nixos/services/aio-smb.nix
    ./hardware-configuration.nix
  ];

  # HP EliteBook 8460p: legacy BIOS, single disk.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "gala";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  services.tailscale.enable = true;
  services.tailscale.extraUpFlags = [ "--accept-routes" ];

  # Kept from the original install on this machine.
  time.timeZone = "Asia/Tokyo";

  services.xserver.xkb.layout = "us";

  # KDE Plasma (Wayland by default, X11 session selectable in SDDM).
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Broadcom wifi firmware; 32-bit GL for Wine/Steam; bluetooth headphones/controllers.
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable32Bit = true;
  hardware.bluetooth.enable = true;

  users.users.wsl = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  nix.settings.trusted-users = [ "wsl" ];

  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  system.stateVersion = "26.05";
}
