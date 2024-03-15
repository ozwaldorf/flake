{ pkgs, username, homeDirectory, ... }: {
  imports = [
    ./sway.nix # window manager
		./gtk.nix # gtk theming
    ./ags/mod.nix # bar, app launcher
    ./wezterm/mod.nix # terminal
    ./zsh.nix # Shell
    ./starship.nix # prompt
    ./git.nix # git
    ./neovim/mod.nix # editor
    ./dev.nix # dev utils
  ];

  home = {
    inherit username homeDirectory;

    sessionPath = [ "$HOME/.local/bin" ];

    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      EDITOR = "nvim";
    };

    packages = with pkgs; [ home-manager webcord gnome.eog pavucontrol ];

    stateVersion = "23.11";
  };

  programs.home-manager.enable = true;
}
