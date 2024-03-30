# ozwaldorf's flake

## Usage
> Note: only `x86_64-linux` can be currently

Install the system and reboot:

```sh
sudo nixos-rebuild boot --upgrade-all --flake "github:ozwaldorf/dotfiles#onix"
reboot
```

Run a headless environment:

```sh
nix run github:ozwaldorf/dotfiles
```

## Development

### AGS

Watch and run the local ags configuration, restarting on save:

```bash
make ags
```
