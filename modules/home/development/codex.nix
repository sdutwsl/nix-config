{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
  home.file.".codex/AGENTS.md".source = ./agent-instructions.md;
}
