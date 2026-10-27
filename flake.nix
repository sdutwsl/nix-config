{
  description = "Wsl's NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-2511.url = "github:NixOS/nixpkgs/nixos-25.11";

    privateConfig = {
      url = "git+ssh://git@github.com/sdutwsl/private-nix-config.git";
      inputs.nixpkgs.follows = "nixpkgs-2511";
    };

    daeuniverse = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.darwin.follows = "";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    vscode-server.url = "github:nix-community/nixos-vscode-server";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.home-manager.follows = "home-manager-stable";
      inputs.nix-openclaw-tools.inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    quickshell-config = {
      url = "git+ssh://git@github.com/sdutwsl/quickshell.git";
      flake = false;
    };

    local-mcp = {
      url = "git+ssh://git@github.com/sdutwsl/local-mcp.git";
      flake = false;
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    nix-claude-code.url = "github:ryoppippi/nix-claude-code";
    muralop = {
      url = "github:sdutwsl/Muralop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    mkHost = import ./lib/mk-host.nix {
      inherit inputs;
    };
    stable = {
      nixpkgs = inputs.nixpkgs-stable;
      home-manager = inputs.home-manager-stable;
    };
    mkHome = { nixpkgs, home-manager }: system: home:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = { inherit inputs; };
        modules = [ home ];
      };
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    blog = system: import ./shells/blog.nix {
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.rust-overlay.overlays.default ];
      };
    };
    gkmas = system: import ./shells/gkmas.nix {
      pkgs = import inputs.nixpkgs { inherit system; };
    };
    android = system: import ./shells/android.nix {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in
  {
    nixosConfigurations = {
      office = mkHost {
        host = ./hosts/office;
        withAgenix = true;
        modules = [
          inputs.privateConfig.nixosModules.officeWork
          inputs.daeuniverse.nixosModules.dae
          inputs.daeuniverse.nixosModules.daed
          inputs.vscode-server.nixosModules.default
          inputs.stylix.nixosModules.stylix
          inputs.muralop.nixosModules.default
          ./modules/nixos/desktop/stylix.nix
          ./modules/nixos/hardware/hotspot.nix
          ./modules/nixos/services/hibernate-to-windows.nix
        ];
      };

      studio = mkHost {
        host = ./hosts/studio;
        modules = [
          inputs.vscode-server.nixosModules.default
          inputs.stylix.nixosModules.stylix
          ./modules/nixos/desktop/stylix.nix
        ];
      };

      aio = mkHost (stable // {
        host = ./hosts/aio;
        withAgenix = true;
        modules = [
          inputs.daeuniverse.nixosModules.dae
          inputs.daeuniverse.nixosModules.daed
          {
            nixpkgs.overlays = [
              (final: prev:
                builtins.removeAttrs
                  (inputs.nix-openclaw.overlays.default final prev)
                  [ "pnpm_11" ]
              )
            ];
          }
        ];
      });

      moki = mkHost (stable // {
        host = ./hosts/moki;
        withAgenix = true;
      });
    };

    homeConfigurations = {
      "wsl@openEruler" = mkHome stable "aarch64-linux" ./hosts/openeruler/home.nix;
      "wsl@ali-server" = mkHome stable "x86_64-linux" ./hosts/ali-server/home.nix;
    };

    devShells = forAllSystems (system: {
      kaola = inputs.privateConfig.devShells.${system}.kaola;
      blog = blog system;
      gkmas = gkmas system;
      android = android system;
    });

    packages = forAllSystems (system: {
      inherit (inputs.privateConfig.packages.${system})
        kaola-dev kaola-dev-us kaola-test-db;
    });
  };
}
