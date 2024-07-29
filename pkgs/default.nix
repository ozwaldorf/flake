{ inputs }:
{
  overlays.default = final: prev: {
    # Fork with sway ipc service
    ags = inputs.ags.packages.${prev.system}.default;

    # wezterm nightly
    wezterm = inputs.wezterm.packages.${prev.system}.default;

    neovim = import ./neovim.nix {
      inherit inputs;
      pkgs = prev;
    };
    webcord = import ./webcord.nix { pkgs = prev; };
    zed-editor = prev.callPackage (import ./zed) { };

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
        outputHash = "sha256-kQ02XmdEtWFpXP0l4nJUHIB5cy9/Fqdcwz2IaMhnems=";
      });
    });

    standalone = import ./standalone.nix {
      inherit inputs;
      pkgs = final;
    };

  };
}
