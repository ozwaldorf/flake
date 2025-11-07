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
    vicinae.url = "github:vicinaehq/vicinae";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.garnix.io"
      "https://vicinae.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
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
              "beekeeper-studio-5.3.4"
            ];
          };
        };
      forAllSystems =
        f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f (pkgsFor system));
    in
    {
      nixosConfigurations = {
        "onix" = nixpkgs.lib.nixosSystem rec {
          specialArgs = {
            inherit
              inputs
              system
              username
              flakeDirectory
              ;
            hostname = "onix";
            homeDirectory = "/home/" + username;
          };
          modules = [
            nixpkgs.nixosModules.readOnlyPkgs
            { nixpkgs.pkgs = pkgsFor system; }
            home-manager.nixosModules.home-manager
            ./systems/onix/configuration.nix
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${username} = import ./home/onix;
              };
            }
          ];
        };

        "seedbox" = nixpkgs.lib.nixosSystem rec {
          specialArgs = {
            inherit
              inputs
              system
              username
              flakeDirectory
              ;
            hostname = "seedbox";
            homeDirectory = "/home/" + username;
          };
          modules = [
            home-manager.nixosModules.home-manager
            nixpkgs.nixosModules.readOnlyPkgs
            { nixpkgs.pkgs = pkgsFor system; }
            ./systems/seedbox/configuration.nix
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${username} = import ./home/seedbox;
              };
            }

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
