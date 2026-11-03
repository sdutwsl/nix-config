# Sogou Pinyin 4.2.1.145 (a Fcitx 4 engine) used from Fcitx 5:
#   app → Fcitx 5 → bridge → private D-Bus → Fcitx 4 + Sogou (sandboxed backend)
# Development history and tests: ~/projects/sougou.
{ pkgs }:
let
  hook = pkgs.stdenv.mkDerivation {
    pname = "sogou-ui-hook";
    version = "0.3.0";
    src = ./hook;
    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
    buildInputs = [ pkgs.dbus ];
  };
  bridge = pkgs.stdenv.mkDerivation {
    pname = "fcitx5-sogou-bridge";
    version = "0.3.1";
    src = ./bridge;
    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
    # Only the Cloud Pinyin module's header; the module itself is loaded at run time.
    buildInputs = [ pkgs.fcitx5 pkgs.qt6Packages.fcitx5-chinese-addons pkgs.systemdLibs ];
  };
  # fcitx-sogoupinyin.so forks `killall -9 sogoupinyin-service` and then starts
  # a new service without waiting, so a late killall killed the new service as
  # well. Only kill processes that predate this call.
  killall = pkgs.writeShellScriptBin "killall" ''
    exec ${pkgs.psmisc}/bin/killall --older-than 1s "$@"
  '';
  fcitx4 = pkgs.callPackage ./fcitx4.nix {
    extra-cmake-modules = pkgs.kdePackages.extra-cmake-modules;
    src = pkgs.fetchurl {
      url = "https://download.fcitx-im.org/fcitx/fcitx-4.2.9.9_dict.tar.xz";
      sha256 = "45aaf19f18774abcd7a18c2729538b63779b1a1883f1e636d364f87c2840a974";
    };
  };
  sogou = pkgs.stdenvNoCC.mkDerivation {
    pname = "sogoupinyin-payload";
    version = "4.2.1.145";
    # The site links ime-sec.gtimg.com (signed, short-lived); ime.gtimg.com
    # serves the same file without a signature.
    src = pkgs.fetchurl {
      url = "https://ime.gtimg.com/pc/dl/gzindex/1680521603/sogoupinyin_4.2.1.145_amd64.deb";
      sha256 = "3111af17a6abddd80b856aa9c1f579a137d69f3d735ead936ddb6e5f08b59f3b";
    };
    nativeBuildInputs = [ pkgs.dpkg ];
    unpackPhase = ''dpkg-deb -x $src .'';
    installPhase = ''
      mkdir -p $out/lib $out/share
      cp -r opt $out/
      cp -r usr/lib/x86_64-linux-gnu/fcitx $out/lib/
      cp -r usr/share/fcitx $out/share/
      # The bundled Qt predates Qt_5.6 required by the actual executables.
      # Preserve private ICU libraries but use one coherent Nix Qt 5 runtime.
      rm $out/opt/sogoupinyin/files/lib/qt5/lib/libQt5*.so.5
      rm -r $out/opt/sogoupinyin/files/lib/qt5/plugins
      rm $out/opt/sogoupinyin/files/bin/qt.conf
      # The watchdog tells Fcitx 4 to quit ~30 s after sogoupinyin-service goes
      # missing, and its /tmp pid file collides across PID namespaces. Fcitx 4
      # restarts the service on demand; sogou-backend restarts Fcitx 4.
      printf '#!/bin/sh\nexit 0\n' > $out/opt/sogoupinyin/files/bin/sogoupinyin-watchdog
      chmod +x $out/opt/sogoupinyin/files/bin/sogoupinyin-watchdog
    '';
    dontFixup = true;
  };
  # Fcitx 5 still draws and places the candidate window; this only gives it
  # the look of Sogou's default skin. Images and icon come from the .deb.
  theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "fcitx5-sogou-theme";
    version = "4.2.1.145";
    src = ./theme;
    nativeBuildInputs = [ pkgs.unzip ];
    installPhase = ''
      skin=$(mktemp -d)
      unzip -q ${sogou}/opt/sogoupinyin/files/share/resources/skin/default/default.zip \
        'ime/ov_page*_on1.svg' -d $skin
      dir=$out/share/fcitx5/themes/sogou
      install -Dm644 theme.conf $dir/theme.conf
      install -Dm644 $skin/ime/ov_pageup_on1.svg $dir/prev.svg
      install -Dm644 $skin/ime/ov_pagedown_on1.svg $dir/next.svg
      install -Dm644 ${sogou}/share/fcitx/imicon/sogoupinyin.png \
        $out/share/icons/hicolor/48x48/apps/fcitx-sogoupinyin.png
    '';
  };
  env = pkgs.buildFHSEnv {
    name = "sogou-env";
    targetPkgs = p: [ fcitx4 sogou killall p.bash p.coreutils p.procps p.dbus
      p.glib p.glibc p.stdenv.cc.cc.lib p.zlib p.libGL p.fontconfig p.freetype
      p.libX11 p.libXext p.libXrender p.libXcursor p.libXinerama p.libXrandr
      p.libXi p.libXtst p.libXScrnSaver p.libXxf86vm p.libICE p.libSM p.libxcb
      p.libxkbcommon p.alsa-lib p.libpulseaudio p.cairo p.pango p.librsvg p.pixman
      p.wayland p.gtk3 p.xorg-server
      p.qt5.qtbase p.qt5.qtdeclarative p.qt5.qtsvg ];
    multiPkgs = _: [];
    extraBuildCommands = ''
      mkdir -p $out/opt
      ln -s ${sogou}/opt/sogoupinyin $out/opt/sogoupinyin
    '';
    profile = ''
      export PATH=/opt/sogoupinyin/files/bin:$PATH
      export LD_LIBRARY_PATH=/opt/sogoupinyin/files/lib:/opt/sogoupinyin/files/lib/qt5/lib:/usr/lib
      export XDG_DATA_DIRS=${sogou}/share:${fcitx4}/share:/usr/share
      export FCITXDIR=/usr
      export QT_QPA_PLATFORM=xcb
      export QT_PLUGIN_PATH=${pkgs.lib.getLib pkgs.qt5.qtbase}/${pkgs.qt5.qtbase.qtPluginPrefix}:${pkgs.lib.getLib pkgs.qt5.qtsvg}/${pkgs.qt5.qtbase.qtPluginPrefix}
      export QML2_IMPORT_PATH=${pkgs.qt5.qtdeclarative}/${pkgs.qt5.qtbase.qtQmlPrefix}
      export LD_PRELOAD=${hook}/lib/libsogou-ui-hook.so
    '';
    runScript = "bash";
    # Sogou runs offline and cannot leave child processes behind.
    unshareNet = true;
    unsharePid = true;
    dieWithParent = true;
  };
  # Sogou's settings open web pages ("添加在线细胞词库") with xdg-open. In
  # the settings sandbox DISPLAY and the session bus are the backend's, so the
  # desktop's xdg-open/kde-open aborted. Hand the URL to the desktop's XDG
  # portal instead: the browser then runs outside the sandbox, with network.
  openUri = pkgs.writeShellScriptBin "xdg-open" ''
    exec ${pkgs.glib.bin}/bin/gdbus call --address "$SOGOU_DESKTOP_BUS" \
      --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop \
      --method org.freedesktop.portal.OpenURI.OpenURI "" "$1" '@a{sv} {}' >/dev/null
  '';
  backend = pkgs.writeShellApplication {
    name = "sogou-backend";
    runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?Missing session runtime directory}"
      umask 077
      state_dir="''${SOGOU_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/sogou-bridge}"
      runtime_dir="$XDG_RUNTIME_DIR/sogou-bridge"
      mkdir -p "$state_dir" "$runtime_dir" "$runtime_dir/backend"
      mkdir -p "$state_dir/home" "$state_dir/config" "$state_dir/cache" "$state_dir/data"
      # Sogou copies its defaults (env.ini ...) from the read-only store with
      # their mode, so its settings window could not save anything.
      chmod -R u+w "$state_dir/home/.config/sogoupinyin" 2>/dev/null || true
      if [[ "''${1:-}" == --settings ]]; then
        # Sogou's settings window, with the backend's configuration and private
        # bus. Sogou names its D-Bus services after DISPLAY (...hotel_<uid>_<n>),
        # so inside the sandbox DISPLAY is the backend's private display, while
        # Qt draws on the desktop via -display. The sandbox itself is started
        # with the desktop's DISPLAY: only that X socket is visible inside.
        address=$(head -n 1 "$runtime_dir/address")
        service=$(tail -n 1 "$runtime_dir/address")
        # shellcheck disable=SC2016 # expanded inside the sandbox
        exec env -u WAYLAND_DISPLAY -u FCITX_DBUS_ADDRESS \
          HOME="$state_dir/home" XDG_CONFIG_HOME="$state_dir/config" \
          XDG_CACHE_HOME="$state_dir/cache" XDG_DATA_HOME="$state_dir/data" \
          XDG_RUNTIME_DIR="$runtime_dir/backend" DBUS_SESSION_BUS_ADDRESS="$address" \
          SOGOU_DESKTOP_BUS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}" \
          SOGOU_DISPLAY=":''${service##*-}" QT_IM_MODULE=xim \
          ${env}/bin/sogou-env -c \
          'desktop=$DISPLAY; export DISPLAY=$SOGOU_DISPLAY PATH=${openUri}/bin:$PATH
          exec sogoupinyin-configtool -display "$desktop"'
      fi
      exec 9>>"$runtime_dir/lock"
      flock -n 9 || exit 0
      # The bridge runs "$launcher --settings" for its settings menu entry.
      readlink -f "$0" > "$runtime_dir/launcher"
      # Creating this file before asking Fcitx 4 to exit stops the loop below.
      rm -f "$runtime_dir/stop"
      quick_exits=0
      while :; do
        log="$state_dir/backend.log"
        if [[ -f "$log" ]] && (( $(stat -c %s "$log") > 1048576 )); then mv "$log" "$log.old"; fi
        started=$SECONDS
        env -u WAYLAND_DISPLAY -u FCITX_DBUS_ADDRESS \
          HOME="$state_dir/home" XDG_CONFIG_HOME="$state_dir/config" \
          XDG_CACHE_HOME="$state_dir/cache" XDG_DATA_HOME="$state_dir/data" \
          XDG_RUNTIME_DIR="$runtime_dir/backend" \
          XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}" \
          SOGOU_BUS_ADDRESS_FILE="$runtime_dir/address" \
          ${env}/bin/sogou-env -c \
          'exec dbus-run-session --config-file=${./session.conf} -- bash ${./backend-inner.sh}' \
          >> "$log" 2>&1 || true
        [[ -e "$runtime_dir/stop" ]] && break
        # Fcitx 4 aborts in Sogou's exit handler, so every exit looks like a
        # crash. Restart it; the bridge reconnects to the new address.
        if (( SECONDS - started < 30 )); then
          if (( ++quick_exits >= 5 )); then
            echo "sogou-backend: $quick_exits quick exits in a row; giving up" >> "$log"
            break
          fi
        else
          quick_exits=0
        fi
        sleep 2
      done
    '';
  };
in { inherit bridge backend theme; }
