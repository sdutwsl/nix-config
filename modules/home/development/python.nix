{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv
    ruff
    pyright
    python3Packages.ipython
    python3Packages.pytest
    python3Packages.debugpy
  ];
}
