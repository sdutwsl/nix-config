{ pkgs, ... }:
let
  font851 = pkgs.stdenv.mkDerivation {
    pname = "851tegakizatsu";
    version = "2";
    src = ../../../assets/fonts;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp *.ttf $out/share/fonts/truetype/
    '';
  };
in
{
  stylix = {
    enable = true;
    image = ../../../assets/wallpapers/black.png;
    # Preserve the current palette instead of extracting colours from the placeholder.
    base16Scheme = {
      scheme = "Stylix";
      author = "Stylix";
      base00 = "192020";
      base01 = "244872";
      base02 = "526d8a";
      base03 = "d48d63";
      base04 = "c9b69b";
      base05 = "f9e1ba";
      base06 = "fcefd3";
      base07 = "f7eed6";
      base08 = "8093a0";
      base09 = "948e9b";
      base0A = "ca7b75";
      base0B = "8493a2";
      base0C = "918f9f";
      base0D = "7e93a6";
      base0E = "8991a0";
      base0F = "8d90a0";
    };
    polarity = "dark";
    fonts = {
      serif = { name = "851tegakizatsu"; package = font851; };
      sansSerif = { name = "851tegakizatsu"; package = font851; };
      monospace = { name = "JetBrainsMono Nerd Font"; package = pkgs.nerd-fonts.jetbrains-mono; };
      emoji = { name = "Noto Color Emoji"; package = pkgs.noto-fonts-color-emoji; };
      sizes = { applications = 10; terminal = 10; desktop = 10; popups = 10; };
    };
  };
}
