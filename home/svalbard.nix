{
  username,
  homeDirectory,
  pkgs,
  ...
}:
{
  imports = [
    ./headless/zsh.nix # Shell
    ./headless/starship.nix # Prompt
    ./headless/git.nix # Git
    ./headless/dev.nix # Dev utils
  ];

  home = {
    inherit username homeDirectory;
    packages = with pkgs; [ screen ];
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
