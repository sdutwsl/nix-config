{ config, pkgs, inputs, ... }:

let
  # stable's qq points at a deb Tencent already removed (404); take it from unstable.
  unstable = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs;[
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    fastfetch
    google-chrome
    firefox
    unstable.qq
    spotify
    wl-clipboard
    zlib
    lzip
    scrcpy
    vlc
    mpv-unwrapped
    curl
    android-tools
    qbittorrent
    unrar
    moonlight-qt
    wineWow64Packages.stableFull

    zulu
    frp
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # programs.obs-studio = {
  #   enable = true;

  #   # optional Nvidia hardware acceleration
  #   package = (
  #     pkgs.obs-studio.override {
  #       cudaSupport = true;
  #     }
  #   );

  #   plugins = with pkgs.obs-studio-plugins; [
  #     wlrobs
  #     obs-backgroundremoval
  #     obs-pipewire-audio-capture
  #     obs-vaapi #optional AMD hardware acceleration
  #     obs-gstreamer
  #     obs-vkcapture
  #   ];
  # };

  imports = [
    ../../profiles/home/core.nix
    ../../profiles/home/desktop.nix
    ../../profiles/home/development.nix
    ../../modules/home/programs/anirss
    ../../modules/home/programs/distrobox
    ../../modules/home/games/subahibi.nix
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

}
