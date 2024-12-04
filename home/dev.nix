{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      neovim

      deno
      nodejs
      gnumake

      inotify-tools
      nix-tree

      ripgrep-all
      ripgrep
      xq

      gh
      bottom
    ];

    sessionVariables = {
      EDITOR = "nvim";
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
      npm_config_prefix = "$HOME/.npm/";
      PATH = "$HOME/.cargo/bin:$HOME/.npm/bin:$PATH";
    };
  };
}
