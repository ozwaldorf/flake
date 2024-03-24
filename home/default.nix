{ pkgs, username, homeDirectory, nvim, ... }: {
  imports = [
    ./sway.nix # window manager
    ./gtk.nix # gtk theming
    ./ags # bar, app launcher
    ./wezterm # terminal
    ./zsh.nix # Shell
    ./starship.nix # prompt
    ./git.nix # git
    ./dev.nix # dev utils
  ];

  home = {
    inherit username homeDirectory;

    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      EDITOR = "nvim";
    };

    packages = with pkgs; [ nvim webcord gnome.eog pavucontrol ];

    stateVersion = "23.11";
  };

  programs.home-manager.enable = true;
}
