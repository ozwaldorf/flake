{ pkgs, username, homeDirectory, ... }: {
  imports = [
    ./zsh.nix # Shell
    ./starship.nix # Prompt
    ./git.nix # Git
    ./dev.nix # Dev utils
  ];

  programs.home-manager.enable = true;
  home = {
    inherit username homeDirectory;
    stateVersion = "24.05";
    sessionVariables = { EDITOR = "nvim"; };
    packages = with pkgs; [ neovim lutgen ];
  };
}
