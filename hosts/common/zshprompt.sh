#!/bin/zsh

autoload -Uz colors && colors
autoload -Uz compinit # Needed for completion, which is often tied to prompt features


HISTFILE="${ZDOTDIR}/history"
setopt appendhistory
HISTSIZE=100000
SAVEHIST=100000


zle_highlight=('paste:none')
autoload edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line


zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion::complete:lsof:*' menu yes select
_comp_options+=(globdots)
compinit

nupdate() {
  local HOSTNAME
  HOSTNAME=$(hostname)
  local FLAKE_PATH="$HOME/nixos-config" 

  if [ -d "$FLAKE_PATH" ]; then
    echo "Building system: $HOSTNAME from $FLAKE_PATH"

    sudo nixos-rebuild switch --flake "$FLAKE_PATH"\#"$HOSTNAME" -v
  else
    echo "Error: Flake path not found at $FLAKE_PATH" >&2
    return 1
  fi
}



alias grab='scripts/alias_scripts/search.sh'
alias color='hyprpicker --format=rgb --autocopy --render-inactive'
alias quarter='convert_and_number() { local filename="$1"; magick "$filename" -crop 50%x50% +adjoin "${filename%.*}_%d.${filename##*.}"; }; convert_and_number'
alias quarter400px='convert_and_number() { local filename="$1"; magick "$filename" -crop 50%x50% +adjoin -resize 400x400! "${filename%.*}_%d.${filename##*.}"; }; convert_and_number'
alias remove-orphans='scripts/alias_scripts/remove-orphans.sh'
alias scan='$HOME/scripts/alias_scripts/virusscan.sh'
alias windows='sudo virsh start win11'
alias comfy='source /home/moonburst/ComfyUI/bin/activate; cd ComfyUI && HSA_OVERRIDE_GFX_VERSION=11.0.0 python main.py'
alias gifmaker='magick -delay 5 -dispose background -loop 0 *.png output.gif'
alias crashlogs='journalctl -b -1 -n 100'
alias bootlogs='journalctl -b -0 -n 300'
alias alarm='$HOME/scripts/alias_scripts/alarm.sh'
alias swaystart='source ~/.zshrc && exec sway'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias unbind-6400='echo "0000:2b:00.0" | sudo tee /sys/bus/pci/devices/0000:2b:00.0/driver/unbind'
alias bind-6400='echo "0000:2b:00.0" | sudo tee /sys/bus/pci/drivers/amdgpu/bind'
alias historycleaner='$HOME/scripts/alias_scripts/historycleaner.sh'
alias nolog='unset HISTFILE'
#alias 1time='$HOME/scripts/alias_scripts/1time.sh'


"$HOME/.config/fastfetch/fastfetch.sh"
PROMPT="%{$fg[yellow]%}[%D{%T}] %{$fg[blue]%}moonburst@%m: %{$fg[green]%}%~%{$reset_color%} $"
