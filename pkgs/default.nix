{ inputs }:
{
  overlays.default = final: prev: {
    # Fork with sway ipc service
    ags = inputs.ags.packages.${prev.system}.default;

    # Update upstream
    sway-contrib.grimshot = prev.sway-contrib.grimshot.overrideAttrs (_: {
      src = prev.fetchFromGitHub {
        owner = "OctopusET";
        repo = "sway-contrib";
        rev = "b7825b218e677c65f6849be061b93bd5654991bf";
        hash = "sha256-ZTfItJ77mrNSzXFVcj7OV/6zYBElBj+1LcLLHxBFypk=";
      };
    });

    # Carburetor gtk theme (patched catpuccin-gtk)
    carburetor-gtk = import ./carburetor-gtk.nix { pkgs = prev; };

    # Carburetor icon theme (patched papirus-icon-theme)
    carburetor-icons = prev.papirus-icon-theme;

    # Webcord with arRPC bridge enabled on startup
    webcord = import ./webcord.nix { pkgs = prev; };

    # Patched to work with hyprland 0.37
    wezterm = import ./wezterm.nix { pkgs = prev; };

    # Standalone neovim configuration
    neovim = import ./neovim.nix {
      inherit inputs;
      pkgs = prev;
    };

    # Update to my fork
    xq = prev.xq.overrideAttrs (old: rec {
      src = prev.fetchFromGitHub {
        owner = "ozwaldorf";
        repo = "xq";
        rev = "bf3f07bf7d142a556604d56101f91b24681d782b";
        hash = "sha256-sCm9Ru0VI/c/RuLmWtK/aht1rwWUfbaFevaIzZVOH5c=";
      };
      cargoDeps = old.cargoDeps.overrideAttrs (_: {
        inherit src;
        outputHash = "sha256-hfjiEXo1et0WQ6iUBFAOTFENjmtNQO/YiQWXcSbFn5E";
      });
    });

    # Gimp Development Version (GTK3)
    gimp-devel = import ./gimp-devel { pkgs = prev; };

    # Standalone shell environment
    standalone = import ./standalone.nix {
      inherit inputs;
      pkgs = final;
    };
  };
}
