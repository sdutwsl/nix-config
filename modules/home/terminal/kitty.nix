{
  pkgs,
  lib,
  ...
}:
{
  programs.kitty = {
    enable = true;

    keybindings = {
      "ctrl+left" = "neighboring_window left";
      "ctrl+right" = "neighboring_window right";
      "ctrl+up" = "neighboring_window top";
      "ctrl+down" = "neighboring_window bottom";
    };

    extraConfig = ''
      include ~/.cache/wal/colors-kitty.conf
    '';
  };
}
