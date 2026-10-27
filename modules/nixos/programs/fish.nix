{ config, pkgs, ... }:
{
  programs.fish.enable = true;

  programs.fish.interactiveShellInit = ''
    function nrs-${config.networking.hostName}
        set config_dir /home/wsl/nix-config
        pushd $config_dir >/dev/null
        nix flake update quickshell-config
        sudo nixos-rebuild switch --flake .#${config.networking.hostName}
        popd >/dev/null
    end
  '';
}
