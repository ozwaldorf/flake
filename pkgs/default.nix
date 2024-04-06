{ inputs }:
{
  overlays.default = (
    final: pkgs: {
      # Fork with sway ipc service
      ags = inputs.ags.packages.${pkgs.system}.default;

      # Update upstream
      sway-contrib.grimshot = pkgs.sway-contrib.grimshot.overrideAttrs (_: {
        src = pkgs.fetchFromGitHub {
          owner = "OctopusET";
          repo = "sway-contrib";
          rev = "b7825b218e677c65f6849be061b93bd5654991bf";
          hash = "sha256-ZTfItJ77mrNSzXFVcj7OV/6zYBElBj+1LcLLHxBFypk=";
        };
      });

      # Carburetor gtk theme (patched catpuccin-gtk)
      carburetor-gtk = import ./carburetor-gtk.nix { inherit pkgs; };

      # Webcord with arRPC bridge enabled on startup
      webcord = import ./webcord.nix { inherit pkgs; };

      # Patched to work with hyprland 0.37
      wezterm = import ./wezterm.nix { inherit pkgs; };

      # Standalone neovim configuration
      neovim = import ./neovim.nix { inherit inputs pkgs; };
    }
  );
}
