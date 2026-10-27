{ pkgs, ... }: {
  home.packages = [ pkgs.copyq ];

  xdg.configFile."autostart/copyq.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=CopyQ
    Comment=Clipboard manager
    Exec=${pkgs.copyq}/bin/copyq --start-server hide
    Icon=copyq
    Terminal=false
    Categories=Utility;
    X-KDE-StartupNotify=false
    X-GNOME-Autostart-enabled=true
  '';
}
