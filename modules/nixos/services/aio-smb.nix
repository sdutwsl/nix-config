{ config, inputs, pkgs, ... }:
let
  smbOptions = [
    "credentials=${config.age.secrets.smb-aio-credentials.path}"
    "uid=1000"
    "gid=100"
    "file_mode=0664"
    "dir_mode=0775"
    "vers=3.0"
    "nouser_xattr"
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=5s"
    "x-systemd.mount-timeout=5s"
  ];
in
{
  environment.systemPackages = [ pkgs.cifs-utils ];

  age.secrets.smb-aio-credentials = {
    file = inputs.privateConfig.lib.secretFile "smb-aio-credentials";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  fileSystems = {
    "/sdcard/d" = {
      device = "//aio/d";
      fsType = "cifs";
      options = smbOptions;
    };
    "/sdcard/e" = {
      device = "//aio/e";
      fsType = "cifs";
      options = smbOptions;
    };
  };
}
