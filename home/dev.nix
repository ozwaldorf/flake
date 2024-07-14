{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      deno
      gnumake

      inotify-tools
      nix-tree

      ripgrep-all
      ripgrep
      xq

      bottom
    ];

    sessionVariables = {
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
      npm_config_prefix = "$HOME/.npm/";
      PATH = "$HOME/.cargo/bin:$HOME/.npm/bin:$PATH";
    };
  };
}
