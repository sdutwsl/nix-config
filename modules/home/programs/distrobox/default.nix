{ pkgs, ... }:

{
  home.packages = [ pkgs.distrobox ];

  xdg.configFile."distrobox/distrobox.conf".text = ''
    container_manager="docker"
  '';

  home.file."apps/vms/distrobox/ubuntu-harmony.ini".source = ./ubuntu-harmony.ini;
  # home.file."apps/vms/distrobox/fedbot.ini".source = ./fedbot.ini;
}
