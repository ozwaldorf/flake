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

    # provides patched wezterm
    error_no_internet_flake = {
      url = "github:ErrorNoInternet/configuration.nix";
    };
  };

  outputs = { self, nixpkgs, home-manager, home-manager-shell, ... }@inputs:
    let
      system = "x86_64-linux";

      overlay = final: prev: {
        swayfx-unwrapped = prev.swayfx-unwrapped.overrideAttrs {
          src = final.fetchFromGitHub {
            owner = "WillPower3309";
            repo = "swayfx";
            rev = "2bd366f3372d6f94f6633e62b7f7b06fcf316943";
            sha256 = "sha256-kRWXQnUkMm5HjlDX9rBq8lowygvbK9+ScAOhiySR3KY=";
          };
        };
        ags = inputs.ags.packages.${system}.default;
        wezterm = inputs.error_no_internet_flake.packages.${system}.wezterm;
        carburetor-gtk = prev.callPackage ./pkgs/gtk.nix { };
        webcord = (import ./pkgs/webcord.nix { pkgs = prev; });
        neovim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
          pkgs = prev;
          module = ./pkgs/neovim.nix;
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ inputs.neovim-nightly-overlay.overlay overlay ];
        config.allowUnfree = true;
      };
      username = "oz";
      hostname = "onix";
      homeDirectory = "/home/${username}";
      args = { inherit inputs pkgs system username hostname homeDirectory; };
    in {
      formatter.${system} = pkgs.nixfmt;

      # Full nixos system and home configuration
      nixosConfigurations = {
        "onix" = nixpkgs.lib.nixosSystem {
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
              home-manager.extraSpecialArgs =
                (args // { installFullDesktop = true; });
              home-manager.users.${username} = import ./home;
            }
          ];
        };
      };

      # Headless standalone home configuration
      homeConfigurations."oz" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home ];
        extraSpecialArgs = args;
      };

      overlays.default = overlay;

      packages.${system} = with pkgs; {
        inherit neovim carburetor-gtk webcord;
      };

      # Use `nix run`
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
    };
}
