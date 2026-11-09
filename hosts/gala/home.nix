{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (google-chrome.override {
      commandLineArgs = [ "--disable-gpu" ];
    })
    mpv
    vlc
    winetricks
    # Galgames usually ship as rar/7z archives.
    unrar
    p7zip
  ];

  programs.fish.shellAliases = {
    sw = "sudo nixos-rebuild switch --flake /etc/nixos#gala";
  };

  imports = [
    ../../modules/home/base.nix
    ../../modules/home/development/git.nix
    # Wine (WoW64) + game launchers.
    ../../modules/home/games/subahibi.nix
    ../../modules/home/games/daydream.nix
  ];
}
