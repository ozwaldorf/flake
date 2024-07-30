{
  description = "ozwaldorf's flake";

  inputs = {
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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    swayfx = {
      url = "github:WillPower3309/swayfx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm = {
      url = "github:wez/wezterm?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lutgen = {
      url = "github:ozwaldorf/lutgen-rs";
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
      # Flake utilities
      custom = import ./pkgs inputs;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            custom.overlays.default

            inputs.swayfx.overlays.insert
            inputs.lutgen.overlays.default
            inputs.carburetor.overlays.default

            (final: prev: {
              ags = inputs.ags.packages.${prev.system}.default;
              wezterm = inputs.wezterm.packages.${prev.system}.default;
            })
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
        ${hostname} = nixpkgs.lib.nixosSystem {
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
      packages = perSystem (
        pkgs: (pkgs.lib.attrsets.getAttrs (builtins.attrNames (self.overlays.default null null)) pkgs)
      );

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
