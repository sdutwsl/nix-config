{ pkgs, lib, ... }:

let
  version = "7.0.6";

  telegramFiles = pkgs.stdenvNoCC.mkDerivation {
    pname = "telegram-desktop-official-files";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/telegramdesktop/tdesktop/releases/download/v${version}/tsetup.${version}.tar.xz";
      hash = "sha256-qUY/E8X0eeHdlRYpq5qjaGOGyt5OthE44BQdsu/PrW0=";
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/telegram-desktop
      cp -r Telegram/* $out/opt/telegram-desktop/

      chmod +x $out/opt/telegram-desktop/Telegram
      chmod +x $out/opt/telegram-desktop/Updater || true

      runHook postInstall
    '';
  };

  telegramDesktopFHS = pkgs.buildFHSEnv {
    name = "telegram-desktop";

    targetPkgs =
      pkgs: with pkgs; [
        glibc
        zlib
        glib
        dbus
        fontconfig
        freetype

        # Wayland / keyboard
        wayland
        libxkbcommon
        xkeyboard_config

        # OpenGL / graphics
        libGL
        mesa
        libdrm
        vulkan-loader

        # Audio
        alsa-lib
        pulseaudio

        # Common runtime libs
        nss
        nspr
        expat
        cups
        gtk3
        at-spi2-atk
        at-spi2-core

        # Keep these available because Telegram/Qt may dlopen them.
        # These are the new package names, not deprecated xorg.* aliases.
        libx11
        libxext
        libxfixes
        libxcb
        libxi
        libsm
        libice
        libxrender
        libxrandr
        libxcursor
        libxdamage
        libxcomposite
      ];

    profile = ''
      export XKB_CONFIG_ROOT=${pkgs.xkeyboard_config}/share/X11/xkb
      export QT_QPA_PLATFORM=wayland

      unset QT_STYLE_OVERRIDE
      unset QT_QPA_PLATFORMTHEME

      export DESKTOP_SESSION=plasma
      export XDG_CURRENT_DESKTOP=KDE

      # Hide harmless Qt log:
      # qt.waylandcompositor.hardwareintegration: Failed to initialize EGL display...
      export QT_LOGGING_RULES="qt.waylandcompositor.hardwareintegration=false''${QT_LOGGING_RULES:+;$QT_LOGGING_RULES}"
    '';

    runScript = "${telegramFiles}/opt/telegram-desktop/Telegram";
  };

  telegramDesktopItem = pkgs.makeDesktopItem {
    name = "org.telegram.desktop";
    desktopName = "Telegram Desktop";
    genericName = "Messenger";
    comment = "Official desktop version of Telegram messaging app";
    exec = "telegram-desktop -- %u";
    icon = "telegram";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeTypes = [
      "x-scheme-handler/tg"
    ];
    startupWMClass = "TelegramDesktop";
  };

  telegramDesktop = pkgs.symlinkJoin {
    name = "telegram-desktop-${version}";
    paths = [
      telegramDesktopFHS
      telegramDesktopItem
    ];

    meta = {
      description = "Official Telegram Desktop binary release wrapped in FHS environment";
      homepage = "https://desktop.telegram.org/";
      license = lib.licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "telegram-desktop";
    };
  };
in
{
  home.packages = [
    telegramDesktop
  ];
}
