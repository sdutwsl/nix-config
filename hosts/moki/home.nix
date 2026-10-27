{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    wget
    vim
    git
    wireguard-tools
  ];

  imports = [
    ../../modules/home/base.nix
  ];
}
