{ config
, pkgs
, inputs
, ...
}:

{
  home.packages = with pkgs; [
    home-manager

    qqmusic
    google-chrome
    firefox
    spotify
    # netease-cloud-music-gtk
    git
    gh
    subversion
    ripgrep
    fd
    # bottles
    # discord
    fastfetch
    unzip
    remmina
    wl-clipboard
    # moonlight-qt
    zlib
    lzip
    scrcpy
    mpv-unwrapped
    flameshot
    obs-studio
    curl
    alacritty
    swaybg
    wttrbar
    gimp
    xdg-utils
    pavucontrol
    wofi
    (commitizen.overridePythonAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_invalid_command" ];
    }))
    yt-dlp
    kdePackages.polkit-kde-agent-1
    # rofi-wayland
    grim
    slurp
    gitkraken
    playerctl
    xclip
    nixpkgs-fmt
    postman
    libvlc
    xsel
    jq

    mpvpaper
    # genymotion
    wrangler
    # beekeeper-studio
    jetbrains.datagrip

    calibre
    imagemagick

    inotify-tools
    ncdu
    p3x-onenote
    nixfmt

    fuzzel

    android-tools
    nmap
    baidupcs-go
    opencode
    libnotify

    usb-modeswitch
    iw
    htop
    smem
    wireguard-tools
    btop
    file
    iperf3
    wpsoffice-cn
    (writeShellScriptBin "rwp" "${builtins.readFile ../../scripts/randomwallpaper.sh}")
    (writeShellScriptBin "compress_png" "${builtins.readFile ../../scripts/compress_png.sh}")
    (writeShellScriptBin "arwp" "while true; do rwp; sleep 15; done")
    (writeShellScriptBin "ytdh" ''
      exec yt-dlp \
        --cookies-from-browser chrome \
        -f "bv*+ba/b" \
        -P "$HOME/Videos/Hidamari" \
        "$@"
    '')
    (writeShellScriptBin "adbs" "${builtins.readFile ../../scripts/adbs.sh}")
    (pkgs.writeScriptBin "hello" ''
      #!${pkgs.python3}/bin/python3
      print("Hello, World!")
    '')
    android-studio
    #    unityhub
    # (pkgs.soundwireserver.overrideAttrs (oldAttrs: {
    #   src = pkgs.fetchzip {
    #     url = "https://georgielabs.net/SoundWire_Server_linux64.tar.gz";
    #     hash = "sha256-TECuQ5WXpeikc9tXEE/wVBnRbdYd0OaIFFhsBRmaukA=";
    #   };
    # }))
  ];

  home.file = {};

  programs.fish = {
    enable = true;
    shellAliases = {
      sw = "sudo nixos-rebuild switch";
      gc = "sudo nix-collect-garbage -d";
      yunzai = "code --folder-uri ssh://fedbot:bots/Yunzai";
    };
  };

  imports = [
    inputs.privateConfig.homeManagerModules.workTools
    inputs.plasma-manager.homeModules.plasma-manager
    ../../profiles/home/ai.nix
    ../../profiles/home/core.nix
    ../../profiles/home/desktop.nix
    ../../profiles/home/development.nix
    ../../modules/home/programs/qq.nix
    ../../modules/home/programs/distrobox
    ../../modules/home/desktop/plasma
    ../../modules/home/desktop/quickshell
    ../../modules/home/desktop/pywal
    ../../modules/home/desktop/sway
    ../../modules/home/desktop/gtk
    ../../modules/home/development/python.nix
    ../../modules/home/development/node.nix
    ../../modules/home/security/pass.nix
    # ../../modules/home/desktop/dunst
    ../../modules/home/desktop/copyq
    ../../modules/home/terminal/kitty.nix
    ../../modules/home/services/rime-frost.nix
  ];
}
