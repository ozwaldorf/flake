{
  description = "ozwaldorf's flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm = { url = "github:ErrorNoInternet/configuration.nix"; };
    # TODO: fixme
    swayfx = {
      url = "github:WillPower3309/swayfx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim.url = "path:./neovim";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            swayfx-unwrapped = prev.swayfx-unwrapped.overrideAttrs {
              src = final.fetchFromGitHub {
                owner = "WillPower3309";
                repo = "swayfx";
                rev = "2bd366f3372d6f94f6633e62b7f7b06fcf316943";
                sha256 = "sha256-kRWXQnUkMm5HjlDX9rBq8lowygvbK9+ScAOhiySR3KY=";
              };
            };
            wezterm = inputs.wezterm.packages.${system}.wezterm;
            neovim = inputs.nvim.packages.${system}.default;
          })
        ];
        config.allowUnfree = true;
      };
    in {
      formatter.x86_64-linux = pkgs.nixfmt;
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
              home-manager.users.${username} = import ./home;
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
