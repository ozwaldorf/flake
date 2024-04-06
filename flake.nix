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

    swayfx.url = "github:ozwaldorf/swayfx";

    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    prismlauncher.url = "github:PrismLauncher/PrismLauncher";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      home-manager-shell,
      ...
    }@inputs:
    let
      # Flake utilities
      makePkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            inputs.swayfx.overlays.default
            inputs.prismlauncher.overlays.default
            custom.overlays.default
          ];
          config.allowUnfree = true;
        };
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
      ];
      perSystem = f: nixpkgs.lib.genAttrs allSystems (system: f (makePkgs system));

      # System variables (nixos and home)
      system = "x86_64-linux";
      custom = import ./pkgs { inherit inputs; };
      pkgs = makePkgs system;
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

      # Export the standalone custom packages and the default overlay for applying them;
      inherit (custom) overlays;
      packages = perSystem (pkgs: {
        inherit (pkgs)
          neovim
          ags
          swayfx-unwrapped
          carburetor-gtk
          ;

        default = pkgs.standalone;
      });

      # Default `nix run` for the headless home configuration
      apps = perSystem (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.standalone}/bin/zsh";
        };
      });

      # `nix fmt`
      formatter = perSystem (pkgs: pkgs.nixfmt-rfc-style);
    };
}
