{ pkgs, ... }: {
  fonts = {
    enableDefaultPackages = false;
    packages = with pkgs; [
      material-design-icons
      font-awesome

      noto-fonts
      source-code-pro
      source-sans
      source-serif
      source-han-sans
      source-han-serif

      julia-mono
      dejavu_fonts
    ];
  };
}
