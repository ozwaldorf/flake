{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
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

    sessionVariables = {
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
      PATH = "$HOME/.cargo/bin:$PATH";
    };
  };
}
