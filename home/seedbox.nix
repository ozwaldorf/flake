{ username, homeDirectory, ... }: {
  imports = [
    ../shared/zsh.nix # Shell
    ../shared/starship.nix # Prompt
    ../shared/git.nix # Git
    ../shared/dev.nix # Dev utils
  ];

  home = {
    inherit username homeDirectory;
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
