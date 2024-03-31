{
  description = "ozwaldorf's flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-shell = {
      url = "sourcehut:~dermetfan/home-manager-shell";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Needed to make wezterm work with Hyprland 0.37
    error_no_internet_flake.url = "github:ErrorNoInternet/configuration.nix";
  };

  outputs = { self, nixpkgs, home-manager, home-manager-shell, ... }@inputs:
    let
      system = "x86_64-linux";
      overlays = import ./pkgs { inherit inputs system; };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ inputs.neovim-nightly-overlay.overlay overlays.default ];
        config.allowUnfree = true;
      };

      username = "oz";
      hostname = "onix";
      homeDirectory = "/home/${username}";

      args = { inherit inputs pkgs system username hostname homeDirectory; };
    in {
      # Export the standalone custom packages and the default overlay for them;
      inherit overlays;
      packages.${system} = {
        inherit (pkgs) neovim ags swayfx-unwrapped carburetor-gtk;
      };

      # Full nixos system and home configuration
      nixosConfigurations = {
        "onix" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = args;
          modules = [
            # System level config
            ./system/configuration.nix

            # User level config
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = args;
                users.${username} = import ./home;
              };
            }
            home-manager.nixosModules.home-manager
          ];
        };
      };

      # Headless standalone home configuration
      homeConfigurations."oz" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home ];
        extraSpecialArgs = (args // { installFullDesktop = false; });
      };

      # Default `nix run` for the headless home configuration
      apps.${system} = {
        default = {
          type = "app";
          program = (let
            shell = home-manager-shell.lib { inherit self system; };
            entry = pkgs.symlinkJoin {
              name = "entry";
              paths = [ shell ];
              nativeBuildInputs = with pkgs; [ makeWrapper ];
              installPhase = ''
                wrapProgram $out/bin/home-manager-shell --add-flag "-U oz" --add-flag "-i ./home" --add-flag "-c"
              '';
            };
          in "${entry}/bin/home-manager-shell");
        };
      };

      # `nix fmt`
      formatter.${system} = pkgs.nixfmt;
    };
}
