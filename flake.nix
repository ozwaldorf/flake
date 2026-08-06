{
  description = "ozwaldorf's flake";

  inputs = {
    # Nix and nixos
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Configuration librarires
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
    zoom-sync = {
      url = "github:ozwaldorf/zoom-sync";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Source only: its own flake pins hyprland git, but plugins are ABI bound
    # to the compositor they load into, so the package is built below against
    # the patched nixpkgs hyprland instead.
    hyprcapture = {
      url = "github:gfhdhytghd/HyprCapture";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      determinate,
      ...
    }@inputs:
    let
      # Absolute path to the directory containing this flake.
      # Used for creating "out of store" symlinks. For example, mostly
      # in order to allow in-app setting changes to modify the flake.
      flakeDirectory = "/etc/nixos";

      # Custom package overlay and list of package names
      overlay = import ./pkgs inputs;
      names = builtins.attrNames (overlay null null);
      # Derive pkgs for a system
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            inputs.carburetor.overlays.insert
            # inputs.neovim-nightly-overlay.overlays.default
            (final: prev: {
              # Force insert flake packages that dont have builtin overlays.
              zoom-sync = inputs.zoom-sync.packages.${system}.default;
              # Relax glaze pin so it accepts nixpkgs' 8.0.0.
              # Remove once NixOS/nixpkgs#549253 lands.
              hyprland = prev.hyprland.overrideAttrs (old: {
                postPatch = ''
                  substituteInPlace CMakeLists.txt start/CMakeLists.txt hyprpm/CMakeLists.txt \
                    --replace-fail "glaze 7...<8" "glaze"
                ''
                + old.postPatch;
              });
              # Built through callPackage rather than the upstream flake output
              # so it compiles against the hyprland above, matching the ABI of
              # the compositor it is loaded into.
              hyprcapture = final.callPackage "${inputs.hyprcapture}/nix/package.nix" {
                src = inputs.hyprcapture;
              };
              vimPlugins = prev.vimPlugins // {
                catppuccin-nvim = prev.vimPlugins.catppuccin-nvim.overrideAttrs {
                  doCheck = false;
                  nvimRequireCheck = null;
                };
              };
            })
            # Custom packages
            overlay
          ];
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [ "beekeeper-studio-5.5.3" ];
          };
        };
      # Derive flake outputs for packages on all systems
      forAllSystems =
        f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f (pkgsFor system));

      # Derive various nixos systems
      makeSystems =
        items:
        builtins.listToAttrs (
          map (
            {
              username,
              hostname,
              system,
              config,
              home,
            }:
            {
              name = hostname;
              value = nixpkgs.lib.nixosSystem rec {
                specialArgs = {
                  inherit username hostname;
                  inherit inputs flakeDirectory;
                  homeDirectory = "/home/" + username;
                };
                modules = [
                  # Fixed nix packages
                  nixpkgs.nixosModules.readOnlyPkgs
                  { nixpkgs.pkgs = pkgsFor system; }
                  determinate.nixosModules.default

                  # system configuration
                  config
                  # home manager configuration
                  home-manager.nixosModules.home-manager
                  {
                    home-manager = {
                      useGlobalPkgs = true;
                      useUserPackages = true;
                      extraSpecialArgs = specialArgs;
                      users.${username} = import home;
                    };
                  }
                ];
              };
            }
          ) items
        );
    in
    {
      nixosConfigurations = makeSystems [
        {
          hostname = "onix";
          username = "oz";
          system = "x86_64-linux";
          home = ./home/onix.nix;
          config = ./systems/onix/configuration.nix;
        }
        {
          hostname = "guide";
          username = "oz";
          system = "x86_64-linux";
          home = ./home/guide.nix;
          config = ./systems/guide/configuration.nix;
        }
        {
          hostname = "svalbard";
          username = "oz";
          system = "x86_64-linux";
          home = ./home/svalbard.nix;
          config = ./systems/svalbard/configuration.nix;
        }
      ];

      # Flake outputs
      overlays.default = overlay;

      # Export all custom packages from the overlay
      packages = forAllSystems (pkgs: pkgs.lib.attrsets.getAttrs names pkgs);

      # `nix run` for a standalone headless environment starting with zsh
      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.standalone}/bin/zsh";
        };
      });

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
