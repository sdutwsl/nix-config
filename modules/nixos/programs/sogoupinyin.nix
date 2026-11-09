{ inputs, pkgs, ... }:

let
  unstable = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  sogou = import ../../../pkgs/sogoupinyin { pkgs = unstable; };
in
{
  # Sogou Pinyin in Fcitx 5 via a sandboxed Fcitx 4 backend.
  i18n.inputMethod.fcitx5.addons = [
    sogou.bridge
    sogou.theme
  ];

  systemd.user.services.sogou-backend = {
    description = "Sogou Pinyin backend for Fcitx 5";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${sogou.backend}/bin/sogou-backend";
  };
}
