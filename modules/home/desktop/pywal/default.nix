{ config, pkgs, lib, ... }:

let
  wallpaper = "${config.home.homeDirectory}/Pictures/wallpaper.png";
in
{
  home.packages = [ pkgs.pywal ];

  systemd.user.services.pywal = {
    Unit = {
      Description = "Generate Pywal color scheme";
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = wallpaper;
    };

    Service = {
      Type = "oneshot";

      Environment = [
        "PATH=${lib.makeBinPath [
          pkgs.imagemagick
          pkgs.coreutils
        ]}"
      ];

      ExecStart =
        "${pkgs.pywal}/bin/wal -q -n -i ${wallpaper}";
    };

    Install.WantedBy = [
      "graphical-session.target"
    ];
  };
}
