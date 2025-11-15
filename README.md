# ozwaldorf's flake

## Overview

```
├── home           : Home manager configurations
│   ├── graphical  : Graphical configuration
│   ├── headless   : Headless configuration
│   └── *.nix      : Per-system home entrypoints
├── pkgs           : Custom package overlay
└── systems        : Per-system nixos configurations
```

## Usage

### Installing on a new system

1. Clone the repo
```sh
git clone https://github.com/ozwaldorf/flake && cd flake
```

2. Edit `flakeDirectory` path to where you cloned the repo in `flake.nix` (or, move the repo to /etc/nixos)

3. Copy your system and hardware configuration into a new host directory under `systems/my-host/*.nix`

4. Initialize home manager configuration with a new host file under `home/my-host.nix`

5. Install the system and reboot (x86_64-linux):

```sh
sudo nixos-rebuild switch --upgrade-all --flake . && reboot
```

### Standalone neovim:

```sh
nix run github:ozwaldorf/flake\#neovim
```

### Standalone headless environment:

```sh
nix run github:ozwaldorf/flake
```

## Cache

Binary caches are provided via https://garnix.io
