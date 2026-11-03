{ pkgs, ... }:
{
  home.packages = [
    pkgs.antigravity-cli
  ];
  home.file.".gemini/GEMINI.md".source = ./agent-instructions.md;
}
