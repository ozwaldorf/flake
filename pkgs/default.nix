inputs: final: prev: {
  webcord = import ./webcord.nix prev;
  xq = import ./xq.nix prev;
  zed-editor = import ./zed prev;

  neovim = import ./neovim.nix {
    inherit inputs;
    pkgs = prev;
  };
  standalone = import ./standalone.nix {
    inherit inputs;
    pkgs = final;
  };
}
