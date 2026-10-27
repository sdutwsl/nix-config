{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.privateConfig.homeManagerModules.attendanceWaybar ];

  home.packages = [
    pkgs.playerctl
    pkgs.urlencode
  ];
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        reload_style_on_change = true;

        modules-left = [
          "clock"
          "sway/workspaces"
          "custom/weather"
          "sway/window"
        ];
        modules-center = [
          # "custom/media"
          "custom/lyric"
        ];
        modules-right = [
          "pulseaudio"
          "network"
          "power-profiles-daemon"
          "cpu"
          "memory"
          # "temperature"
          "custom/disk"
          "backlight"
          # "keyboard-state"
          "tray"
          # "custom/power"
        ];

        "custom/hello-from-waybar" = {
          format = "hello {}";
          max-length = 40;
          interval = "once";
          exec = pkgs.writeShellScript "hello-from-waybar" ''
            echo "from within waybar"
          '';
        };

        "sway/window" = {
          max-length = 200;
          separate-outputs = true;
        };
        "sway/workspaces" = {
          format = "{icon}";
          # "on-scroll-up" = "hyprctl dispatch workspace e+1";
          # "on-scroll-down" = "hyprctl dispatch workspace e-1";
        };

        "keyboard-state" = {
          "numlock" = true;
          "capslock" = true;
          "format" = "{name} {icon}";
          "format-icons" = {
            "locked" = "";
            "unlocked" = "";
          };
        };

        "tray" = {
          # "icon-size": 21,
          "spacing" = 10;
        };
        "clock" =
          let
            copyClock = pkgs.writeShellScript "copy-clock.sh" ''
              ${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S' | ${pkgs.wl-clipboard}/bin/wl-copy
            '';
          in
          {
            interval = 1;
            format = "{:%Y-%m-%d %H:%M:%S}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";

            on-click = "${copyClock}";
          };
        "cpu" = {
          "format" = "{usage}% ";
          "tooltip" = false;
        };
        "memory" = {
          "format" = "{}% ";
        };
        "custom/disk" = {
          "format" = "{}";
          "max-length" = 40;
          "interval" = 10; # // Remove this if your script is endless and write in loop
          # "exec" = pkgs.writeShellScript "get-lyric.sh" "${builtins.readFile ../../../../scripts/get-lyric.sh}";
          "exec" = "${pkgs.writeShellApplication {
            name = "disk-usage";
            runtimeInputs = [
              pkgs.util-linux
              pkgs.coreutils
              pkgs.gawk
              pkgs.findutils
            ];
            text = builtins.readFile ../../../../scripts/disk_usage.sh;
          }}/bin/disk-usage";
        };
        "temperature" = {
          #// "thermal-zone": 2,
          #// "hwmon-path": "/sys/class/hwmon/hwmon2/temp1_input",
          "critical-threshold" = 80;
          #// "format-critical": "{temperatureC}°C {icon}",
          "format" = "{temperatureC}°C {icon}";
          "format-icons" = [
            ""
            ""
            ""
          ];
        };
        "backlight" = {
          #// "device": "acpi_video1",
          "format" = "{percent}% {icon}";
          "format-icons" = [
            ""
            ""
            ""
            ""
            ""
            ""
            ""
            ""
            ""
          ];
        };
        "battery" = {
          "states" = {
            #// "good": 95,
            "warning" = 30;
            "critical" = 15;
          };
          "format" = "{capacity}% {icon}";
          "format-full" = "{capacity}% {icon}";
          "format-charging" = "{capacity}% ";
          "format-plugged" = "{capacity}% ";
          "format-alt" = "{time} {icon}";
          #// "format-good": ""// An empty format will hide the module
          #// "format-full": "",
          "format-icons" = [
            ""
            ""
            ""
            ""
            ""
          ];
        };

        "network" = {
          "format-wifi" = "{essid} ({signalStrength}%) ";
          "format-ethernet" = "{ipaddr}/{cidr} ";
          "tooltip-format" = "{ifname} via {gwaddr} ";
          "format-linked" = "{ifname} (No IP) ";
          "format-disconnected" = "Disconnected ⚠";
          "format-alt" = "{ifname}: {ipaddr}/{cidr}";
        };
        "pulseaudio" = {
          "scroll-step" = 1; # %, can be a float
          "format" = "{volume}% {icon} {format_source}";
          "format-bluetooth" = "{volume}% {icon} {format_source}";
          "format-bluetooth-muted" = " {icon} {format_source}";
          "format-muted" = " {format_source}";
          "format-source" = "{volume}% ";
          "format-source-muted" = "";
          "format-icons" = {
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = [
              ""
              ""
              ""
            ];
          };
          "on-double-click" = "pavucontrol";
        };

        "custom/media" = {
          "format" = " {}";
          "max-length" = 40;
          "interval" = 1; # // Remove this if your script is endless and write in loop
          "exec" = pkgs.writeShellScript "media-player.sh" "${builtins.readFile ../../../../scripts/media-player.sh}";
        };
        "custom/lyric" =
          let
            getLyric = pkgs.writeShellApplication {
              name = "get-lyric";
              runtimeInputs = [
                pkgs.playerctl
                pkgs.curl
                pkgs.jq
                pkgs.coreutils
                pkgs.gawk
              ];
              text = builtins.readFile ../../../../scripts/get-lyric.sh;
            };

            copyLyric = pkgs.writeShellApplication {
              name = "copy-lyric";
              runtimeInputs = [
                pkgs.wl-clipboard
              ];
              text = ''
                cache="''${XDG_RUNTIME_DIR:-/tmp}/waybar-current-lyric"

                if [ -s "$cache" ]; then
                  wl-copy < "$cache"
                fi
              '';
            };
          in
          {
            format = "{}";
            exec = "${getLyric}/bin/get-lyric";
            on-click = "${copyLyric}/bin/copy-lyric";

            # 点击时不要重启 exec 脚本
            exec-on-event = false;

            # 防止歌词里的 < > & 被 Waybar 当成 markup
            escape = true;
          };
        "custom/weather" = {
          "format" = "{}";
          "exec" = pkgs.writeShellScript "get-weather.sh" "${builtins.readFile ../../../../scripts/get-weather.sh}";
          "interval" = 300;
        };
        "custom/power" = {
          "format" = "⏻ ";
          "tooltip" = false;
          "menu" = "on-click";
          "menu-file" = "$HOME/.config/waybar/power_menu.xml"; # // Menu file in resources folder
          "menu-actions" = {
            "shutdown" = "shutdown";
            "reboot" = "reboot";
            "suspend" = "systemctl suspend";
            "hibernate" = "systemctl hibernate";
          };
        };
      };
    };
    style = ''
      * {
          border: none;
          border-radius: 0;
          font-family: "Ubuntu Nerd Font";
          font-size: 14px;
          min-height: 0;
      }

      window#waybar {
          background: rgba(0, 0, 0, 0.3);
          color: #eeeeee;
          opacity: 1;

      }

      #window {
          font-weight: bold;
          font-family: "Ubuntu";
      }

      /*
      #workspaces {
          padding: 0 5px;
      }
      */

      #workspaces button {
          padding: 0 5px;
          background: transparent;
          color: white;
          border-top: 2px solid transparent;
      }

      #workspaces button.focused {
          color: #c9545d;
          border-top: 2px solid #c9545d;
      }

      #mode {
          background: #64727D;
          border-bottom: 3px solid white;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #custom-spotify,
      #tray,
      #mode {
          padding: 0 3px;
          margin: 0 2px;
      }

      #clock {
          font-weight: bold;
      }

      #battery {}

      #battery icon {
          color: red;
      }

      #battery.charging {}

      @keyframes blink {
          to {
              background-color: #ffffff;
              color: black;
          }
      }

      #battery.warning:not(.charging) {
          color: white;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      #cpu {}

      #memory {}

      #network {}

      #network.disconnected {
          background: #f53c3c;
      }

      #pulseaudio {}

      #pulseaudio.muted {}

      #custom-spotify {
          color: rgb(102, 220, 105);
      }

      #tray {
      }
    '';
  };
  home.file = {
    ".config/waybar/power_menu.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <interface>
        <object class="GtkMenu" id="menu">
          <child>
          <object class="GtkMenuItem" id="suspend">
            <property name="label">Suspend</property>
              </object>
        </child>
        <child>
              <object class="GtkMenuItem" id="hibernate">
            <property name="label">Hibernate</property>
              </object>
        </child>
          <child>
              <object class="GtkMenuItem" id="shutdown">
            <property name="label">Shutdown</property>
              </object>
          </child>
          <child>
            <object class="GtkSeparatorMenuItem" id="delimiter1"/>
          </child>
          <child>
          <object class="GtkMenuItem" id="reboot">
            <property name="label">Reboot</property>
          </object>
          </child>
        </object>
      </interface>
    '';
  };
}
