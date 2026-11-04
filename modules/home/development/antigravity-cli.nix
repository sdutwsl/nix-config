{ inputs, pkgs, ... }:
let
  unstable = import inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  home.packages = [
    (pkgs.antigravity-cli or unstable.antigravity-cli)
  ];
  home.file.".gemini/GEMINI.md".source = ./agent-instructions.md;
}
