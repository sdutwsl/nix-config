{ inputs
, pkgs
, ...
}:
let
  version = "4.1.1-2026-07-10";
  src = pkgs.fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-T1StKQLs1vb9xWgLc1R/gNVCO/RwsBI3pXmi5bPK7us=";
  };
  wechat = pkgs.callPackage (inputs.nixpkgs + "/pkgs/by-name/we/wechat/linux.nix") {
    pname = "wechat";
    inherit version src;
    inherit (pkgs.wechat) meta;
  };
in
{
  home.packages = [ wechat ];
}
