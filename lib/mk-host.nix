{ inputs }:
{
  host,
  system ? "x86_64-linux",
  user ? "wsl",
  modules ? [ ],
  withAgenix ? false,
  nixpkgs ? inputs.nixpkgs,
  home-manager ? inputs.home-manager,
}:
let
  agenixModules = nixpkgs.lib.optionals withAgenix [
    inputs.agenix.nixosModules.default
    {
      environment.systemPackages = [ inputs.agenix.packages.${system}.default ];
    }
  ];
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs; };
  modules = modules ++ agenixModules ++ [
    host
    ({ pkgs, ... }: {
      programs.fish.enable = true;
      users.users.${user}.shell = pkgs.fish;
    })
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.users.${user} = import (host + "/home.nix");
    }
  ];
}
