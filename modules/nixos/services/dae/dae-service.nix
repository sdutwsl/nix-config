{
  systemd.services.dae = {
    after = [ "sing-box.service" ];
    requires = [ "sing-box.service" ];
  };
}
