{ config
, pkgs
, lib
, ...
}: {
  stylix.targets.sway.useWallpaper = false;

  home.sessionVariables = {
    # GTK_IM_MODULE = "fcitx";
    # QT_IM_MODULE = "fcitx";
    # XMODIFIERS = "@im=fcitx";

    GDK_BACKEND = "wayland,x11";
    QT_QPA_PLATFORM = "wayland;xcb";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    XDG_CURRENT_DESKTOP = "Sway";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Sway";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_SCALE = "1";
    XCURSOR_SIZE = "32";
  };
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # Fixes common issues with GTK 3 apps
    config = rec {
      # monitors
      output = {
        "DP-1" = {
          pos = "2560 180";
        };
        "HDMI-A-1" = {
          pos = "0 0";
        };
      };
      modifier = "Mod4";
      # Use kitty as default terminal
      terminal = "kitty";
      startup = [
        {
          command = "waybar";
        }
        {
          command = "swaybg -i ~/Pictures/wallpaper.png";
          always = true;
        }
        {
          command = "fcitx5";
        }
        {
          command = "sleep 1&&qq"; # QQ should run after waybar initialized
        }
        {
          command = "flatpak run com.tencent.WeChat";
        }
      ];
      floating = {
        modifier = "Mod4";
        criteria = [
          {
            class = "QQ";
          }
          {
            class = ".scrcpy-wrapped";
          }
          {
            class = "wechat";
          }
          {
            title = ".*微信.*";
          }
          {
            instance = "spotify";
          }
        ];
      };
      keybindings =
        let
          modifier = config.wayland.windowManager.sway.config.modifier;
        in
        lib.mkOptionDefault {

          # 自定义应用快捷键
          "Control+Alt+left" = "exec playerctl previous";
          "Control+Alt+right" = "exec playerctl next";

          "${modifier}+f1" = "exec rofi -show run";
          "${modifier}+f2" = "exec google-chrome-stable --enable-wayland-ime --wayland-text-input-version=3";
          "${modifier}+f3" = "exec nemo";
          "${modifier}+f4" = "exec code";

          "${modifier}+f5" = "exec qq";
          "${modifier}+f6" = "exec flatpak run com.tencent.WeChat";
          "${modifier}+f7" = "exec spotify --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3";
          "${modifier}+f8" = "exec steam --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3";

          "Print" = "exec grim -g \"$(slurp -d)\" - | wl-copy";
        };

      bars = [
        # {
        #   command = "${pkgs.waybar}/bin/waybar";
        # }
      ];

      window = {
        titlebar = false;
        border = 0;
        commands = [
          {
            criteria = {
              title = ".*Visual Studio Code.*";
            };
            command = "opacity 0.9";
          }
          {
            criteria = {
              app_id = "kitty";
            };
            command = "opacity 0.8";
          }

        ];
      };
    };
  };
}
