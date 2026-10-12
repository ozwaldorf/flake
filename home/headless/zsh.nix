{
  config,
  lib,
  pkgs,
  inputs,
  hostname,
  flakeDirectory,
  osConfig ? { },
  ...
}:
let
  # Init scripts generated at build time rather than by a process per shell
  initScript =
    name: script:
    pkgs.runCommand "${name}-init.zsh" { } ''
      export HOME=$TMPDIR
      ${script}
    '';

  starship = lib.getExe config.programs.starship.package;
  direnv = osConfig.programs.direnv or { enable = false; };
in
{
  # weekly prebuilt database for nix-locate, comma and the launcher
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home.packages = with pkgs; [
    eza
    bat
    curl
    onefetch
    weechat
    # without recode, whose charset tables cost ~17ms per run for a no-op
    # UTF-8 to UTF-8 conversion
    ((fortune.override { withOffensive = true; }).overrideAttrs { buildInputs = [ ]; })
  ];

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  # zsh init for these is sourced from build-time scripts below
  programs.starship.enableZshIntegration = false;

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  # command corrector, invoked as `fuck` after a failed command
  programs.pay-respects = {
    enable = true;
    enableZshIntegration = false;
    options = [
      "--alias"
      "fuck"
    ];
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
      strategy = [
        "history"
        "completion"
      ];
    };
    syntaxHighlighting.enable = true;
    autocd = true;
    enableVteIntegration = true;
    # enableCompletion = false; # autocomplete will compinit on its own

    # Key the dump on the system and user profiles so -C can skip the
    # audit and rescan, while a switch still starts a fresh dump
    completionInit = ''
      autoload -U compinit
      () {
        local dir=''${XDG_CACHE_HOME:-$HOME/.cache}/zsh
        local dump=$dir/zcompdump-''${''${''${:-/run/current-system}:A:t}[1,32]}-''${''${''${:-/etc/profiles/per-user/$USER}:A:t}[1,32]}
        if [[ ! -e $dump ]]; then
          mkdir -p $dir
          rm -f $dir/zcompdump-*(N)
        fi
        compinit -C -d $dump
      }
    '';

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
      # {
      #   name = "zsh-autocomplete";
      #   src = pkgs.zsh-autocomplete;
      #   file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      # }
      # {
      #   name = "vi-mode";
      #   src = pkgs.zsh-vi-mode;
      #   file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      # }
    ];

    shellAliases = {
      ls = "eza -lh --git --icons always"; # better ls
      la = "ls -a";
      lg = "la --git-ignore";
      l = "lg";
      cat = "bat"; # better cat
      cp = "cp -i"; # Confirm before overwriting something
      df = "df -h"; # Human-readable sizes
      free = "free -m"; # Show sizes in MB
      clip = "wl-copy"; # clipboard pipe
      jq = "jaq";
      tree = "eza --tree";
      curl = "curl -s";
      commit = "git commit";
      add = "git add";
      rebase = "git stash && git pull --rebase && git stash pop";
      n = "nvim";
      c = "cargo";
      wq = "exit";
      switch = "sudo nixos-rebuild switch --flake ${flakeDirectory}\\#${hostname}";
      # Always run from the latest hourly builds
      claude = "nix run github:sadjow/claude-code-nix -- --dangerously-skip-permissions";
      codex = "nix run github:sadjow/codex-cli-nix -- --yolo";
    };

    sessionVariables = {
      # Let's break up words more
      WORDCHARS = "*?[]~=&;!#$%^(){}<>";
      PATH = "$HOME/.deno/bin:$HOME/.local/bin:$PATH";

    };

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        source ${initScript "dircolors" "${pkgs.coreutils}/bin/dircolors -b > $out"}
      '')
      (lib.mkIf direnv.enable (
        lib.mkOrder 550 ''
          source ${initScript "direnv" "${lib.getExe direnv.package} hook zsh > $out"}
        ''
      ))
      (lib.mkOrder 910 ''
        if [[ $options[zle] = on ]]; then
          source ${initScript "fzf" "${lib.getExe config.programs.fzf.package} --zsh > $out"}
        fi
      '')
      ''
        if [[ $TERM != "dumb" ]]; then
          source ${initScript "starship" ''
            export STARSHIP_CONFIG=${config.home.file.${config.programs.starship.configPath}.source}
            ${starship} init zsh --print-full-init | grep -v '^PROMPT2=' > $out
            printf 'PROMPT2=%q\n' "$(${starship} prompt --continuation)" >> $out
          ''}
        fi
        source ${
          initScript "pay-respects" "${lib.getExe config.programs.pay-respects.package} zsh ${lib.escapeShellArgs config.programs.pay-respects.options} > $out"
        }
      ''
      (lib.mkBefore ''
        ## Options section
        setopt interactive_comments                                     # Enable autocomplete
        setopt complete_aliases                                         # Complete aliased commands
        setopt correct                                                  # Auto correct mistakes
        setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
        setopt rcexpandparam                                            # Array expension with parameters
        setopt nocheckjobs                                              # Don't warn about running processes when exiting
        setopt numericglobsort                                          # Sort filenames numerically when it makes sense
        setopt AUTO_MENU

        # # autocompletions config
        zstyle ':completion:*:*:*:default' menu yes select search

        # zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
        # zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"       # Colored completion (different colors for dirs/files/etc)
        # zstyle ':completion:*' rehash true                              # automatically find new executables in path
        # zstyle ':completion::complete:*' gain-privileges 1
        # zstyle -e ':autocomplete:*:*' list-lines 'reply=( $(( LINES / 3 )) )'

        # # Cycle/enter autocomplete with tab
        # bindkey              '^I' menu-select
        # bindkey "$terminfo[kcbt]" menu-select

        # Navigate words
        bindkey '^[[1;5D' backward-word                                 # Ctrl + right key
        bindkey '^[[1;5C' forward-word                                  # Ctrl + left key
        bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
        # bindkey '^[[Z' undo                                             # Shift+tab undo last action

        function nixpkgs() {
          NIXPKGS_ALLOW_UNFREE=1 nix shell "''${@/#/nixpkgs#}"
        }

        # report the working directory to the terminal (OSC 7)
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

        # Advanced customization of fzf options via _fzf_comprun function
        # - The first argument to the function is the name of the command.
        # - You should make sure to pass the rest of the arguments ($@) to fzf.
        _fzf_comprun() {
          local command=$1
          shift

          case "$command" in
            cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
            ssh)          fzf --preview 'dig {}'                                   "$@" ;;
            nvim)         fzf --preview 'bat -n --color=always {}'                 "$@" ;;
          esac
        }
      '')
      ''
        fortune -s

        # A command handed in by the launcher, run as though typed at the
        # first prompt, so the shell stays once it exits
        if [[ -n $LAUNCHER_RUN ]]; then
          _launcher_run=$LAUNCHER_RUN
          unset LAUNCHER_RUN
          function _launcher-run() {
            add-zle-hook-widget -d line-init _launcher-run
            BUFFER=$_launcher_run
            unset _launcher_run
            zle accept-line
          }
          autoload -Uz add-zle-hook-widget
          zle -N _launcher-run
          add-zle-hook-widget line-init _launcher-run
        fi
      ''
      # Case insensitive globbing, set last since it makes compinit and the
      # plugins' globs scan all of /nix/store
      (lib.mkAfter ''
        setopt nocaseglob
      '')
    ];
  };
}
