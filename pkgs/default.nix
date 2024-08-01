inputs: {
  overlays.default = final: prev: {
    neovim = import ./neovim.nix {
      inherit inputs;
      pkgs = prev;
    };
    webcord = import ./webcord.nix { pkgs = prev; };
    xq = import ./xq.nix { pkgs = prev; };
    zed-editor = import ./zed prev;

    standalone = import ./standalone.nix {
      inherit inputs;
      pkgs = final;
    };
  };
}
