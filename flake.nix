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

    ags = {
      url = "github:ozwaldorf/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
      ];
      forAllSystems = f: genAttrs allSystems (system: f system);

      makePkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ custom.overlays.default ];
          config.allowUnfree = true;
        };

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

      # Headless standalone home configuration
      homeConfigurations."oz" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/headless.nix ];
        extraSpecialArgs = args;
      };

      # Export the standalone custom packages and the default overlay for applying them;
      inherit (custom) overlays;
      packages = forAllSystems (
        system:
        let
          pkgs = makePkgs system;
        in
        {
          inherit (pkgs)
            neovim
            ags
            swayfx-unwrapped
            carburetor-gtk
            ;
        }
      );

      # Default `nix run` for the headless home configuration
      apps = forAllSystems (
        system:
        let
          pkgs = makePkgs system;
        in
        {
          default = {
            type = "app";
            program = (
              let
                shell = home-manager-shell.lib { inherit self system; };
                entry = pkgs.symlinkJoin {
                  name = "entry";
                  paths = [ shell ];
                  nativeBuildInputs = with pkgs; [ makeWrapper ];
                  installPhase = ''
                    wrapProgram $out/bin/home-manager-shell --add-flag "-U oz" --add-flag "-i ./home" --add-flag "-c"
                  '';
                };
              in
              "${entry}/bin/home-manager-shell"
            );
          };
        }
      );

      # `nix fmt`
      formatter = forAllSystems (system: (makePkgs system).nixfmt-rfc-style);
    };
}
