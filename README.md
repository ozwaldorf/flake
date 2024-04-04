# ozwaldorf's flake

## Usage

Install the system and reboot (x86_64-linux):

```sh
git clone https://github.com/ozwaldorf/flake && cd flake

# copy your hardware config in
cp /etc/nixos/hardware-configuration.nix system

# build and reboot
sudo nixos-rebuild boot --upgrade-all --flake . && reboot
```

Run standalone neovim:

```sh
nix run github:ozwaldorf/flake#neovim
```

## Cache

Binary caches are provided via https://garnix.io
