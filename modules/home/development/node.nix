{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs
    pnpm
    yarn
    typescript
    prettier
    eslint_d
  ];
}
