#!/bin/zsh

autoload -Uz colors && colors
HISTFILE="${ZDOTDIR}/history"
setopt appendhistory
HISTSIZE=1000
SAVEHIST=1000
setopt autocd extendedglob nomatch menucomplete
setopt interactive_comments
unsetopt BEEP # Beeping is annoying
zle_highlight=('paste:none')
autoload edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line # Bind Ctrl-e to edit-command-line in editor
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search


zsh_add_file() {
    local file_path="$ZDOTDIR/$1"
    if [[ -f "$file_path" ]]; then
        source "$file_path"
    # else
        # Optional: uncomment for debugging missing files
        # echo "Warning: Zsh config file '$file_path' not found. Ensure it exists in $ZDOTDIR." >&2
    fi
}


zsh_add_plugin() {
    local plugin_name="$1"
    local plugin_dir="$ZDOTDIR/plugins/$plugin_name" # Expected plugin install location
    if [[ -d "$plugin_dir" ]]; then
        # Common patterns for plugin loading (try sourcing these)
        if [[ -f "$plugin_dir/$plugin_name.plugin.zsh" ]]; then source "$plugin_dir/$plugin_name.plugin.zsh"; return; fi
        if [[ -f "$plugin_dir/$plugin_name.zsh" ]]; then source "$plugin_dir/$plugin_name.zsh"; return; fi
        if [[ -f "$plugin_dir/init.zsh" ]]; then source "$plugin_dir/init.zsh"; return; fi
        # Fallback: source all .zsh files directly in the plugin directory
        for f in "$plugin_dir"/*.zsh; do
            [[ -f "$f" ]] && source "$f"
        done
    # else
        # echo "Warning: Zsh plugin '$plugin_name' not found at '$plugin_dir'." >&2
    fi
}


zsh_add_completion() {
    local comp_file_path="$ZDOTDIR/completion/$1"
    if [[ -f "$comp_file_path" ]]; then
        # Add the directory containing the completion to fpath
        # Assumes $1 is something like "_fnm" and the file is $ZDOTDIR/completion/_fnm
        fpath+=("$(dirname "$comp_file_path")")
    # else
        # echo "Warning: Zsh completion file '$comp_file_path' not found." >&2
    fi
}

zsh_add_file "functions"
zsh_add_file "exports"
zsh_add_file "aliases"

zsh_add_plugin "zsh-users/zsh-autosuggestions"
zsh_add_plugin "zsh-users/zsh-syntax-highlighting"
zsh_add_plugin "hlissner/zsh-autopair"

autoload -Uz compinit
zmodload zsh/complist
zstyle ':completion:*' menu select
 zstyle ':completion::complete:lsof:*' menu yes select 
_comp_options+=(globdots) 

compinit

if [[ -f "/usr/share/fzf/completion.zsh" ]]; then
    source "/usr/share/fzf/completion.zsh"
elif [[ -f "/usr/share/doc/fzf/examples/completion.zsh" ]]; then
    source "/usr/share/doc/fzf/examples/completion.zsh"
fi
if [[ -f "/usr/share/fzf/key-bindings.zsh" ]]; then
    source "/usr/share/fzf/key-bindings.zsh"
elif [[ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]]; then
    source "/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Custom FZF default command example (uncomment if you use ripgrep)
export FZF_DEFAULT_COMMAND='rg --hidden -l ""'

cd() {
    builtin cd "$@" && ls
}


update-profile() {

local HOSTNAME
  HOSTNAME=$(hostname)
  local FLAKE_PATH="/home/moonburst/nixos-config"

  if [ -d "$FLAKE_PATH" ]; then
    echo "Building system: $HOSTNAME from $FLAKE_PATH"

    sudo nixos-rebuild switch --flake "$FLAKE_PATH"\#"$HOSTNAME"
  else
    echo "Error: Flake path not found at $FLAKE_PATH" >&2
    return 1
  fi
}


$XDG_CONFIG_HOME/fastfetch/fastfetch.sh
PROMPT="%{$fg[yellow]%}[%D{%T}] %{$fg[blue]%}moonburst@%m: %{$fg[green]%}%~%{$reset_color%} $"
