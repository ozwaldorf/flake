{ pkgs, lib, username, homeDirectory, installFullDesktop ? false, ... }: {
  imports = [
    ./zsh.nix # Shell
    ./starship.nix # Prompt
    ./git.nix # Git
    ./dev.nix # Dev utils
  ] ++ lib.optionals installFullDesktop [ ./desktop.nix ];

  home = {
    inherit username homeDirectory;
    sessionVariables = { EDITOR = "nvim"; };
    packages = with pkgs; [ neovim lutgen ];
    stateVersion = "24.05";
  };

  programs.home-manager.enable = true;
}
