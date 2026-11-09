{config, pkgs, ...} : {
  # for Nvidia GPU
  services.xserver.videoDrivers = ["nvidia"]; # will install nvidia-vaapi-driver by default
  hardware.nvidia = {
    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix
    # package = config.boot.kernelPackages.nvidiaPackages.stable;

    # required by most wayland compositors!
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
  };
  hardware.nvidia-container-toolkit.enable = true; # for nvidia-docker
  systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists = "/proc/driver/nvidia/version";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}