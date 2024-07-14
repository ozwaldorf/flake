{ inputs, pkgs }:
let
  username = "standalone";
  homeDirectory = "/tmp/${username}";
  module = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      {
        home = {
          inherit username homeDirectory;
          stateVersion = "24.05";
          packages = with pkgs; [
            neovim
            xq
            btm
          ];
        };
      }
      ../home/zsh.nix
      ../home/starship.nix
    ];
  };
in
pkgs.symlinkJoin {
  name = "standalone";
  paths = [
    module.config.home-files
    module.config.home.packages
    module.config.home.activationPackage # debug
  ];
  buildInputs = with pkgs; [ makeWrapper ];
  postBuild = ''
    # Wrap starship with the generated config
    wrapProgram $out/bin/starship \
      --set STARSHIP_CONFIG "$out/.config/starship.toml"

    # Wrap zsh with the generated config
    wrapProgram $out/bin/zsh \
      --run "
        # Setup .nix-profile/
        rm -rf ${homeDirectory}
        mkdir -p ${homeDirectory}/.nix-profile
        ln -s $out ${homeDirectory}/.nix-profile
        ln -s $out/bin ${homeDirectory}/.nix-profile
        ln -s $out/sbin ${homeDirectory}/.nix-profile
        ln -s $out/lib ${homeDirectory}/.nix-profile
        ln -s $out/libexec ${homeDirectory}/.nix-profile
        ln -s $out/etc ${homeDirectory}/.nix-profile
        export PATH="$out/bin:\$PATH"
      " --set ZDOTDIR "$out"
  '';
}
