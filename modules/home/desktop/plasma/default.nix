{ config, ... }:
{
  stylix.targets.kde.useWallpaper = false;

  # KWin 6.7 can scan out rapidly updating surfaces without carrying over
  # opacity set on the parent window by window rules.
  systemd.user.sessionVariables = {
    KWIN_DRM_NO_DIRECT_SCANOUT = "1";
    KWIN_USE_OVERLAYS = "0";
  };

  programs.plasma = {
    enable = true;
    workspace.wallpaper = "${config.home.homeDirectory}/Pictures/wallpaper.png";

    shortcuts = {
      kwin = {
        # Window management
        "Window Close" = "Alt+F4";
        "Window Maximize" = "Meta+PgUp";
        "Window Minimize" = "Meta+PgDown";
        "Window Quick Tile Bottom" = "Meta+Down";
        "Window Quick Tile Left" = "Meta+Left";
        "Window Quick Tile Right" = "Meta+Right";
        "Window Quick Tile Top" = "Meta+Up";
        "Window to Next Screen" = "Meta+Shift+Right";
        "Window to Previous Screen" = "Meta+Shift+Left";
        "Kill Window" = "Meta+Ctrl+Esc";

        # Desktop switching
        "Switch One Desktop Down" = "Meta+Ctrl+Down";
        "Switch One Desktop Up" = "Meta+Ctrl+Up";
        "Switch One Desktop to the Left" = "Meta+Ctrl+Left";
        "Switch One Desktop to the Right" = "Meta+Ctrl+Right";
        "Switch to Desktop 1" = "Ctrl+F1";
        "Switch to Desktop 2" = "Ctrl+F2";
        "Switch to Desktop 3" = "Ctrl+F3";
        "Switch to Desktop 4" = "Ctrl+F4";

        # Window moving between desktops
        "Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
        "Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
        "Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
        "Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";

        # Window focus switching
        "Switch Window Down" = "Meta+Alt+Down";
        "Switch Window Left" = "Meta+Alt+Left";
        "Switch Window Right" = "Meta+Alt+Right";
        "Switch Window Up" = "Meta+Alt+Up";
        "Walk Through Windows" = "Alt+Tab";
        "Walk Through Windows (Reverse)" = "Alt+Shift+Backtab";
        "Walk Through Windows of Current Application" = "Alt+`";
        "Walk Through Windows of Current Application (Reverse)" = "Alt+~";

        # Overview / Expose
        "Overview" = "Meta+W";
        "Grid View" = "Meta+G";
        "Show Desktop" = "Meta+D";
        "Expose" = "Ctrl+F9";
        "ExposeAll" = "Ctrl+F10";
        "ExposeClass" = "Ctrl+F7";

        # Zoom
        "view_actual_size" = "Meta+0";
        "view_zoom_in" = [ "Meta+=" "Meta++" ];
        "view_zoom_out" = "Meta+-";
      };

      ksmserver = {
        "Lock Session" = [
          "Screensaver"
          "Meta+L"
        ];

        "Log Out" = "Ctrl+Alt+Del";
      };

      plasmashell = {
        "activate task manager entry 1" = "Meta+1";
        "activate task manager entry 2" = "Meta+2";
        "activate task manager entry 3" = "Meta+3";
        "activate task manager entry 4" = "Meta+4";
        "activate task manager entry 5" = "Meta+5";
        "activate task manager entry 6" = "Meta+6";
        "activate task manager entry 7" = "Meta+7";
        "activate task manager entry 8" = "Meta+8";
        "activate task manager entry 9" = "Meta+9";
        "manage activities" = "Meta+Q";
        "next activity" = "Meta+Tab";
        "previous activity" = "Meta+Shift+Tab";
        "stop current activity" = "Meta+S";
        "show dashboard" = "Ctrl+F12";
        "show-on-mouse-pos" = "Meta+V";
        "repeat_action" = "Meta+Ctrl+R";
      };

      krunner = {
        "_launch" = "Search";
      };

      "org.kde.spectacle.desktop" = {
        "ActiveWindowScreenShot" = "Meta+Print";
        "FullScreenScreenShot" = "Shift+Print";
        "RectangularRegionScreenShot" = [ "Meta+Shift+Print" "Ctrl+Alt+A" ];
        "WindowUnderCursorScreenShot" = "Meta+Ctrl+Print";
        "RecordRegion" = "Meta+Shift+R";
        "RecordScreen" = "Meta+Alt+R";
      };
    };

    hotkeys.commands = {
      launch-kitty = {
        name = "Kitty";
        key = "Meta+T";
        command = "kitty";
      };
      launch-dolphin = {
        name = "Dolphin";
        key = "Meta+E";
        command = "dolphin";
      };
      launch-konsole = {
        name = "Konsole";
        key = "Ctrl+Alt+T";
        command = "konsole";
      };
      launch-systemmonitor = {
        name = "System Monitor";
        key = "Meta+Esc";
        command = "plasma-systemmonitor";
      };
      launch-emojier = {
        name = "Emoji Selector";
        key = "Meta+.";
        command = "plasma-emojier";
      };
      song-next = {
        name = "Next Song";
        key = "Ctrl+Alt+Right";
        command = "playerctl next";
      };
      song-previous = {
        name = "Previous Song";
        key = "Ctrl+Alt+Left";
        command = "playerctl previous";
      };
      song-play-pause = {
        name = "Play/Pause";
        key = "Ctrl+Alt+Space";
        command = "playerctl play-pause";
      };
      song-volume-up = {
        name = "Volume Up";
        key = "Ctrl+Alt+Up";
        command = "playerctl --player=spotify volume 0.05+";
      };
      song-volume-down = {
        name = "Volume Down";
        key = "Ctrl+Alt+Down";
        command = "playerctl --player=spotify volume 0.05-";
      };
      screenshot-fullscreen = {
        name = "Screenshot fullscreen to clipboard";
        key = "Print";
        command = "spectacle -f -b -c";
      };
    };

    window-rules = [
      # [ChromeMINI]
      {
        description = "ChromeMINI";
        match = {
          window-class = {
            value = "chrome";
            type = "exact";
            match-whole = false;
          };
          title = {
            value = "Picture in picture";
            type = "exact";
          };
        };
        apply = {
          above = {
            value = true;
            apply = "force";
          };
          opacityactive = {
            value = 80;
            apply = "force";
          };
          opacityinactive = {
            value = 80;
            apply = "force";
          };
          skiptaskbar = {
            value = true;
            apply = "force";
          };
        };
      }

      # [Settings for kitty]
      {
        description = "Settings for kitty";
        match = {
          window-class = {
            value = "kitty";
            type = "exact";
            match-whole = false;
          };
        };
        apply = {
          noborder = {
            value = true;
            apply = "initially";
          };
        };
      }

      # [VSCode]
      {
        description = "VSCode";
        match = {
          window-class = {
            value = "code";
            type = "exact";
            match-whole = false;
          };
        };
        apply = {
          opacityactive = {
            value = 85;
            apply = "force";
          };
          opacityinactive = {
            value = 85;
            apply = "force";
          };
        };
      }

      # [Window settings for .scrcpy-wrapped]
      {
        description = "Window settings for .scrcpy-wrapped";
        match = {
          machine = {
            value = "localhost";
            type = "exact";
          };
          window-class = {
            value = ".scrcpy-wrapped";
            type = "exact";
            match-whole = false;
          };
          window-types = [ "normal" ];
        };
        apply = {
          above = {
            value = true;
            apply = "force";
          };
          noborder = {
            value = true;
            apply = "force";
          };
          opacityactive = {
            value = 70;
            apply = "force";
          };
          opacityinactive = {
            value = 62;
            apply = "force";
          };
          skipswitcher = {
            value = true;
            apply = "force";
          };
          skiptaskbar = {
            value = true;
            apply = "force";
          };
        };
      }

      # [Window settings for calibre-ebook-viewer]
      {
        description = "Window settings for calibre-ebook-viewer";
        match = {
          window-class = {
            value = "calibre-ebook-viewer";
            type = "substring";
            match-whole = true;
          };
          window-types = [ "normal" ];
        };
        apply = {
          opacityactive = {
            value = 88;
            apply = "force";
          };
          opacityinactive = {
            value = 87;
            apply = "force";
          };
        };
      }

      # [Window settings for kitty]
      {
        description = "Window settings for kitty";
        match = {
          window-class = {
            value = "kitty";
            type = "exact";
            match-whole = false;
          };
          title = {
            value = "~";
            type = "exact";
          };
          window-types = [ "normal" ];
        };
        apply = {
          opacityactive = {
            value = 80;
            apply = "force";
          };
          opacityinactive = {
            value = 80;
            apply = "force";
          };
        };
      }

      # [Window settings for 歌词]
      {
        description = "Window settings for 歌词";
        match = {
          window-class = {
            value = "qqmusic";
            type = "exact";
            match-whole = false;
          };
          title = {
            value = "歌词";
            type = "exact";
          };
        };
        apply = {
          above = {
            value = true;
            apply = "force";
          };
          skippager = {
            value = true;
            apply = "force";
          };
          skipswitcher = {
            value = true;
            apply = "force";
          };
          skiptaskbar = {
            value = true;
            apply = "force";
          };
        };
      }

      # [spotifymini]
      {
        description = "spotifymini";
        match = {
          window-class = {
            value = "Chromium-browser";
            type = "exact";
            match-whole = false;
          };
          window-role = {
            value = "pop-up";
            type = "exact";
          };
        };
        apply = {
          opacityactive = {
            value = 80;
            apply = "force";
          };
          opacityinactive = {
            value = 80;
            apply = "force";
          };
        };
      }
    ];

    kscreenlocker = {
      lockOnResume = true;
      timeout = 10;
    };
  };
}
