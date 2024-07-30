inputs: {
  overlays.default = final: prev: {
    neovim = import ./neovim.nix {
      inherit inputs;
      pkgs = prev;
    };
    webcord = import ./webcord.nix { pkgs = prev; };
    xq = import ./xq.nix { pkgs = prev; };
    zed-editor = prev.callPackage (import ./zed) { };

    standalone = import ./standalone.nix {
      inherit inputs;
      pkgs = final;
    };
  };
}
