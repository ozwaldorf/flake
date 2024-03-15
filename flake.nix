{
  description = "ozwaldorf's flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    swayfx = {
      url = "github:WillPower3309/swayfx/workspace-movement";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      nixosConfigurations = {
        "onix" = let
          username = "oz";
          hostname = "onix";
          homeDirectory = "/home/${username}";
          args = {
            inherit inputs pkgs system username hostname homeDirectory;
          };
        in nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = args;
          modules = [
            # System level config
            ./configuration.nix

            # User level config
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = args;
              home-manager.users.${username} = import ./home/home.nix;
            }
          ];
        };

        "headless" = let args = { inherit inputs pkgs system; };
        in nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = args;
          modules = [ ];
        };
      };
    };
}
