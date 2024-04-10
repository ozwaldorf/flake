{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # compilers
    rustup
    deno
    nodejs

    # tools
    gnumake
    fontconfig
    inotify-tools
    nix-tree
    ripgrep-all
  ];
}
