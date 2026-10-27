{ pkgs, inputs, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    brightnessctl
    font-awesome
    inter
    kdotool
    material-design-icons
    nerd-fonts.jetbrains-mono
    networkmanagerapplet
    pywal
    quickshell
  ];

  xdg.configFile."quickshell/default".source = inputs.quickshell-config;

  xdg.configFile."autostart/quickshell.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Quickshell
    Exec=${pkgs.quickshell}/bin/quickshell -c default
    OnlyShowIn=KDE;
    Terminal=false
  '';
}
