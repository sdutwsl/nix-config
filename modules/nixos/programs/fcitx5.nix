{ config, inputs, lib, pkgs, ... }:

let
  unstable = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  fcitx5Package = unstable.qt6Packages.fcitx5-with-addons.override {
    inherit (config.i18n.inputMethod.fcitx5) addons;
  };

  mozcIconFix = pkgs.stdenvNoCC.mkDerivation {
    pname = "fcitx5-mozc-icon-fix";
    version = "1";

    src = unstable.fcitx5-mozc;
    dontUnpack = true;

    nativeBuildInputs = [
      pkgs.imagemagick
      pkgs.findutils
      pkgs.coreutils
    ];

    installPhase = ''
      runHook preInstall
      set -euo pipefail

      primary="$src/share/icons/hicolor/32x32/apps/org.fcitx.Fcitx5.fcitx_mozc.png"

      if [ ! -f "$primary" ]; then
        primary="$src/share/icons/hicolor/128x128/apps/org.fcitx.Fcitx5.fcitx_mozc.png"
      fi

      if [ ! -f "$primary" ]; then
        echo "mozc-icon-fix: no mozc icon found in $src" >&2
        exit 1
      fi

      echo "mozc-icon-fix: using $primary" >&2

      base="org.fcitx.Fcitx5.fcitx_mozc"

      names="
        org.fcitx.Fcitx5.fcitx_mozc
        fcitx_mozc
        fcitx-mozc
        mozc
      "

      for size in 16 22 24 32; do
        for context in apps status; do
          dir="$out/share/icons/hicolor/''${size}x''${size}/$context"
          mkdir -p "$dir"

          magick "$primary" -resize "''${size}x''${size}" "$dir/$base.png"

          for name in $names; do
            if [ "$name" != "$base" ]; then
              ln -sf "$base.png" "$dir/$name.png"
            fi
          done
        done
      done

      runHook postInstall
    '';
  };
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    package = lib.mkForce fcitx5Package;

    fcitx5.addons = with unstable; [
      qt6Packages.fcitx5-configtool
      qt6Packages.fcitx5-chinese-addons
      fcitx5-mozc
      fcitx5-gtk
    ]
    # office, gala, and studio use Sogou (programs/sogoupinyin.nix) instead of Rime.
    ++ lib.optional (!builtins.elem config.networking.hostName [ "office" "gala" "studio" ]) unstable.fcitx5-rime;
  };

  environment.systemPackages = [
    mozcIconFix
  ];
}
