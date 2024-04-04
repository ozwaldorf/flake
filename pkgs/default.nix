{ inputs }:
{
  overlays.default = (
    final: pkgs: {
      # Updated to newer swayfx-git
      swayfx-unwrapped = pkgs.swayfx-unwrapped.overrideAttrs {
        src = pkgs.fetchFromGitHub {
          owner = "WillPower3309";
          repo = "swayfx";
          rev = "2bd366f3372d6f94f6633e62b7f7b06fcf316943";
          sha256 = "sha256-kRWXQnUkMm5HjlDX9rBq8lowygvbK9+ScAOhiySR3KY=";
        };
      };

      # Fork with sway ipc service
      ags = inputs.ags.packages.${pkgs.system}.default;

      # Carburetor gtk theme (patched catpuccin-gtk)
      carburetor-gtk = import ./carburetor-gtk.nix { inherit pkgs; };

      # Webcord with arRPC bridge enabled on startup
      webcord = import ./webcord.nix { inherit pkgs; };

      # Patched to work with hyprland 0.37
      wezterm = import ./wezterm.nix { inherit pkgs; };

      # Standalone neovim configuration
      neovim = inputs.nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
        inherit pkgs;
        extraSpecialArgs = {
          neovim-unwrapped = inputs.neovim.packages.${pkgs.system}.default;
        };
        module = ./neovim.nix;
      };
    }
  );
}
