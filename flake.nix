{
  description = "ozwaldorf's flake";

  inputs = {
    # Nix libraries
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    carburetor = {
      url = "github:ozwaldorf/carburetor";
    };

    # Applications
    ags = {
      url = "github:ozwaldorf/ags";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    zoom-sync = {
      url = "github:ozwaldorf/zoom-sync";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Nixos system variables
      hostname = "onix";
      username = "oz";
      system = "x86_64-linux";

      # Absolute path to the directory containing this flake.
      # Used for creating "out of store" symlinks. For example, mostly
      # in order to allow in-app setting changes to modify the flake.
      flakeDirectory = "/etc/nixos";

      # Flake utilities
      overlay = import ./pkgs inputs;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            inputs.carburetor.overlays.insert
            # inputs.neovim-nightly-overlay.overlays.default
            (final: prev: {
              # Force insert flake packages that dont have builtin overlays.
              ags = inputs.ags.packages.${prev.system}.default;
              zoom-sync = inputs.zoom-sync.packages.${prev.system}.default;
            })

            # Custom packages
            overlay
          ];
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              "beekeeper-studio-5.2.12"
            ];
          };
        };
      forAllSystems =
        f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f (pkgsFor system));

    in
    {
      # Full nixos system and home configuration
      nixosConfigurations = {
        ${hostname} = nixpkgs.lib.nixosSystem rec {
          specialArgs = {
            inherit
              inputs
              system
              username
              hostname
              flakeDirectory
              ;
            homeDirectory = "/home/" + username;
          };

          modules = [
            # Nixpkgs provisioning with overlays
            nixpkgs.nixosModules.readOnlyPkgs
            { nixpkgs.pkgs = pkgsFor system; }

            # System level config
            ./system/configuration.nix

            # User level config
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${username} = import ./home;
              };
            }

            # Modules
            home-manager.nixosModules.home-manager
          ];
        };
      };

      # Flake outputs
      overlays.default = overlay;
      packages = forAllSystems (
        pkgs: (pkgs.lib.attrsets.getAttrs (builtins.attrNames (self.overlays.default null null)) pkgs)
      );

      # `nix run` for a standalone headless environment starting with zsh
      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.standalone}/bin/zsh";
        };
      });

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
