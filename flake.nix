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
    neovim = {
      url = "github:neovim/neovim?dir=contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    swayfx = {
      url = "github:ozwaldorf/swayfx";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.scenefx = {
        url = "github:ozwaldorf/scenefx/fix/blur_effects_nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    prismlauncher = {
      url = "github:PrismLauncher/PrismLauncher";
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
      home-manager-shell,
      swayfx,
      ...
    }@inputs:
    let
      # Flake utilities
      custom = import ./pkgs { inherit inputs; };
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            custom.overlays.default
            inputs.prismlauncher.overlays.default
            inputs.swayfx.overlays.insert
            inputs.hyprland.overlays.default
          ];
          config.allowUnfree = true;
        };
      perSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "i686-linux"
          "x86_64-darwin"
        ] (system: f (pkgsFor system));

      # System variables (nixos and home)
      system = "x86_64-linux";
      pkgs = pkgsFor system;
      username = "oz";
      hostname = "onix";
      homeDirectory = "/home/${username}";
      args = {
        inherit
          inputs
          pkgs
          system
          username
          hostname
          homeDirectory
          ;
      };
    in
    {
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

      # Flake outputs
      inherit (custom) overlays;
      packages = perSystem (pkgs: {
        inherit (pkgs)
          neovim
          ags
          wlroots
          swayfx-unwrapped
          carburetor-gtk
          ;
      });

      # `nix run` for a standalone headless environment starting with zsh
      apps = perSystem (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.standalone}/bin/zsh";
        };
      });

      formatter = perSystem (pkgs: pkgs.nixfmt-rfc-style);
    };
}
