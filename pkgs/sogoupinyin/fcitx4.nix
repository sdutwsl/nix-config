{ lib, stdenv, src, cmake, extra-cmake-modules, pkg-config, gettext, intltool
, libxml2, isocodes, libxkbcommon, libxkbfile, libX11, libXext, libXrender
, libXinerama, libXfixes, libXrandr, libXcursor, libXi, libXtst
, xkeyboard_config, dbus, cairo, pango, gtk3, libuuid, pcre2, makeWrapper, xmodmap, json_c
}:
stdenv.mkDerivation {
  pname = "fcitx4-sogou";
  version = "4.2.9.9";
  inherit src;
  nativeBuildInputs = [ cmake extra-cmake-modules pkg-config gettext intltool makeWrapper ];
  buildInputs = [ libxml2 isocodes libxkbcommon libxkbfile libX11 libXext
    libXrender libXinerama libXfixes libXrandr libXcursor libXi libXtst
    xkeyboard_config dbus cairo pango gtk3 libuuid pcre2 json_c ];
  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DENABLE_QT=OFF" "-DENABLE_QT_IM_MODULE=OFF" "-DENABLE_QT_GUI=OFF"
    "-DENABLE_GTK2_IM_MODULE=OFF" "-DENABLE_GTK3_IM_MODULE=ON"
    "-DENABLE_GIR=OFF" "-DENABLE_OPENCC=OFF" "-DENABLE_ENCHANT=OFF"
    "-DENABLE_PRESAGE=OFF" "-DENABLE_XDGAUTOSTART=OFF"
    "-DENABLE_PINYIN=OFF" "-DENABLE_TABLE=OFF" "-DENABLE_SPELL=OFF"
    "-DXKB_RULES_XML_FILE=${xkeyboard_config}/share/X11/xkb/rules/evdev.xml"
  ];
  postPatch = ''patchShebangs cmake/'';
  postInstall = ''wrapProgram $out/bin/fcitx --prefix PATH : ${xmodmap}/bin'';
  meta = { license = lib.licenses.gpl2Plus; platforms = [ "x86_64-linux" ]; };
}
