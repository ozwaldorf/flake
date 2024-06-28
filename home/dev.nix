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
      ripgrep
      xq
    ];

    sessionVariables = {
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
      npm_config_prefix = "$HOME/.npm/";
      PATH = "$HOME/.cargo/bin:$HOME/.npm/bin:$PATH";
    };
  };
}
