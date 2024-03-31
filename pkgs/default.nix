{ inputs, system }: {
  default = (final: pkgs: {
    swayfx-unwrapped = pkgs.swayfx-unwrapped.overrideAttrs {
      src = pkgs.fetchFromGitHub {
        owner = "WillPower3309";
        repo = "swayfx";
        rev = "2bd366f3372d6f94f6633e62b7f7b06fcf316943";
        sha256 = "sha256-kRWXQnUkMm5HjlDX9rBq8lowygvbK9+ScAOhiySR3KY=";
      };
    };
    ags = inputs.ags.packages.${system}.default;
    carburetor-gtk = import ./carburetor-gtk.nix { inherit pkgs; };
    webcord = import ./webcord.nix { inherit pkgs; };
    neovim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
      inherit pkgs;
      module = ./neovim.nix;
    };
    wezterm = inputs.error_no_internet_flake.packages.${system}.wezterm;
  });
}
