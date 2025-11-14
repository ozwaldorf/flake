{
  pkgs,
  hostname,
  flakeDirectory,
  ...
}:
{
  home.packages = with pkgs; [
    fzf
    eza
    bat
    curl
    tree
    comma
    onefetch
    (fortune.override { withOffensive = true; })
  ];

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;

    history = {
      save = 1000000;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };

    # inline history suggestions
    autosuggestion = {
      enable = true;
      highlight = "fg=244";
    };
    syntaxHighlighting.enable = true;
    autocd = true;
    enableVteIntegration = true;
    enableCompletion = false; # autocomplete will compinit on its own

    plugins = [
      {
        name = "zsh-window-title";
        src = pkgs.fetchFromGitHub {
          owner = "olets";
          repo = "zsh-window-title";
          rev = "v1.2.0";
          sha256 = "RqJmb+XYK35o+FjUyqGZHD6r1Ku1lmckX41aXtVIUJQ=";
        };
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];

    shellAliases = with { ls_args = "--git --icons"; }; {
      ls = "eza -lh ${ls_args}";
      la = "eza -lah ${ls_args}";
      l = "eza -lah ${ls_args}";
      lg = "eza -lah ${ls_args} --git-ignore";
      cat = "bat";
      cp = "cp -i"; # Confirm before overwriting something
      df = "df -h"; # Human-readable sizes
      free = "free -m"; # Show sizes in MB
      clip = "wl-copy";
      curl = "curl -s";
      commit = "git commit";
      add = "git add";
      rebase = "git stash && git pull --rebase && git stash pop";
      ytop = "ytop -spfa";
      n = "nvim";
      c = "cargo";
      wq = "exit";
      icat = "wezterm imgcat";
      fuck = "thefuck";
      switch = "sudo nixos-rebuild switch --flake ${flakeDirectory}\\#${hostname}";
      nixpkg = "echo 'use ,'";
    };

    sessionVariables = {
      # Let's break up words more
      WORDCHARS = "*?[]~=&;!#$%^(){}<>";
      PATH = "$HOME/.deno/bin:$PATH";
    };

    initExtraFirst = ''
      ## Options section
      setopt interactive_comments                                     # Enable autocomplete
      setopt complete_aliases                                         # Complete aliased commands
      setopt correct                                                  # Auto correct mistakes
      setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
      setopt nocaseglob                                               # Case insensitive globbing
      setopt rcexpandparam                                            # Array expension with parameters
      setopt nocheckjobs                                              # Don't warn about running processes when exiting
      setopt numericglobsort                                          # Sort filenames numerically when it makes sense

      # autocompletions config
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"       # Colored completion (different colors for dirs/files/etc)
      zstyle ':completion:*' rehash true                              # automatically find new executables in path
      zstyle ':completion::complete:*' gain-privileges 1
      zstyle -e ':autocomplete:*:*' list-lines 'reply=( $(( LINES / 3 )) )'

      # Cycle/enter autocomplete with tab
      bindkey              '^I' menu-select
      bindkey "$terminfo[kcbt]" menu-select

      # Navigate words
      bindkey '^[[1;5D' backward-word                                 # Ctrl + right key
      bindkey '^[[1;5C' forward-word                                  # Ctrl + left key
      bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
      # bindkey '^[[Z' undo                                             # Shift+tab undo last action

      function nixpkgs() {
        NIXPKGS_ALLOW_UNFREE=1 nix shell "''${@/#/nixpkgs#}"
      }

      # foot integration
      function osc7-pwd() {
          emulate -L zsh # also sets localoptions for us
          setopt extendedglob
          local LC_ALL=C
          printf '\e]7;file://%s%s\e\' $HOST ''${PWD//(#m)([^@-Za-z&-;_~])/%''${(l:2::0:)$(([##16]#MATCH))}}
      }
      function chpwd-osc7-pwd() {
          (( ZSH_SUBSHELL )) || osc7-pwd
      }
      add-zsh-hook -Uz chpwd chpwd-osc7-pwd
    '';

    initExtra = ''
      fortune -s
    '';
  };
}
