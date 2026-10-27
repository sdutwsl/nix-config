{ config, inputs, lib, pkgs, ... }:

let
  agenixExec = config.systemd.user.services.agenix.Service.ExecStart;
  agenixMount = if builtins.isList agenixExec then builtins.head agenixExec else agenixExec;
in
{
  imports = [
    inputs.privateConfig.homeManagerModules.openErulerWork
    inputs.agenix.homeManagerModules.default
    ../../profiles/home/ai.nix
    ../../modules/home/base.nix
    ../../modules/home/development/git.nix
    ../../modules/home/development/node.nix
    ../../modules/home/development/python.nix
  ];

  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    curl
    wget
    vim
    tmux
    rsync
    unzip
    zip
    tree
    file
    jq
    ripgrep
    fd
    btop
    iperf3
  ];

  age = {
    secretsDir = "${config.home.homeDirectory}/.local/state/agenix";
    secretsMountPoint = "${config.home.homeDirectory}/.local/state/agenix.d";
  };

  home.activation.agenixMount = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${agenixMount}
  '';

  programs.git.signing.signByDefault = lib.mkForce false;

  programs.fish.enable = true;
}
