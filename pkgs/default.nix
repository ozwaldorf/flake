inputs: final: prev: {
  webcord = import ./webcord.nix prev;
  # xq = import ./xq.nix prev;

  neovim = import ./neovim.nix {
    inherit inputs;
    pkgs = prev;
  };
  standalone = import ./standalone.nix {
    inherit inputs;
    pkgs = final;
  };

  snd-hda-intel = prev.callPackage (import ./snd-hda-intel.nix) { };
  beammp-server = prev.callPackage (import ./beammp-server.nix) { };
}
