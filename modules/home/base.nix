{ config, lib, pkgs, ... }: {
  home.username = "wsl";
  home.homeDirectory = "/home/wsl";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
  home.sessionVariables = {
    EDITOR = "vim";
    NIXOS_OZONE_WL = "1";
  };

  programs.fish.enable = true;
  programs.bash.enable = config.targets.genericLinux.enable;
  programs.bash.bashrcExtra = lib.mkIf config.targets.genericLinux.enable ''
    [ -f /etc/bashrc ] && . /etc/bashrc
  '';
  programs.bash.initExtra = lib.mkIf config.targets.genericLinux.enable ''
    if [[ $- == *i* && -t 0 && "$(${pkgs.procps}/bin/ps -o comm= -p "$PPID")" != fish ]]; then
      export SHELL=${pkgs.fish}/bin/fish
      exec ${pkgs.fish}/bin/fish
    fi
  '';

  home.activation.removeOldFiles = lib.hm.dag.entryBefore [ "checkFilesChanged" ] ''
    gtkrc="$HOME/.gtkrc-2.0"
    if [ -f "$gtkrc" ] && [ ! -L "$gtkrc" ]; then
      rm "$gtkrc"
    fi
  '';
}
