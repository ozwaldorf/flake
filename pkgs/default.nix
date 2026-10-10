inputs: final: prev: {
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
  opennow = prev.callPackage (import ./opennow.nix) { };
  niri = import ./niri.nix { inherit (prev) niri; };
  claude-desktop = final.callPackage ./claude-desktop.nix { src = inputs.claude-desktop; };
}
