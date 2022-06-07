# Use powerline
USE_POWERLINE="true"

# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi

# Alias
alias cat="bat"
ls_args="--git --icons"
alias ls="exa -lh $ls_args"
alias la="exa -lah $ls_args"
alias l="exa -lah $ls_args"
alias lg="exa -lah $ls_args --git-ignore"
alias commit="git commit"
alias add="git add"

# Environment
source ~/.env
export EDITOR="code"
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export PATH="/home/oz/bin:/home/oz/.cargo/bin:$PATH"

# Completions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
zstyle ':completion::complete:*' gain-privileges 1

eval $(starship init zsh)

nerdfetch
