{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 100000;

    histFile = "$HOME/.local/state/zsh/history";

    shellAliases = {
      ll = "ls -l";
      ".." = "cd ..";
      nix-switch = "sudo nixos-rebuild switch --flake ~/nixos-config";
      wallpaper = "/home/moonburst/nixos-config/hosts/moonbeauty/scripts/wallpaper.sh";

      grab = "scripts/alias_scripts/search.sh";
      color = "hyprpicker --format=rgb --autocopy --render-inactive";
      remove-orphans = "scripts/alias_scripts/remove-orphans.sh";
      scan = "$HOME/scripts/alias_scripts/virusscan.sh";
      windows = "sudo virsh start win11";
      comfy = "source /home/moonburst/ComfyUI/bin/activate; cd ComfyUI && HSA_OVERRIDE_GFX_VERSION=11.0.0 python main.py";
      gifmaker = "magick -delay 5 -dispose background -loop 0 *.png output.gif";
      crashlogs = "journalctl -b -1 -n 100";
      bootlogs = "journalctl -b -0 -n 300";
      alarm = "$HOME/scripts/alias_scripts/alarm.sh";
      swaystart = "exec sway";
      update-grub = "sudo grub-mkconfig -o /boot/grub/grub.cfg";
      unbind-6400 = "echo '0000:2b:00.0' | sudo tee /sys/bus/pci/devices/0000:2b:00.0/driver/unbind";
      bind-6400 = "echo '0000:2b:00.0' | sudo tee /sys/bus/pci/drivers/amdgpu/bind";
      historycleaner = "$HOME/scripts/alias_scripts/historycleaner.sh";
      nolog = "unset HISTFILE";
      uhorizon = "curl -L https://github.com/Fchat-Horizon/Horizon/releases/latest/download/F-Chat.Horizon-linux-x86_64.AppImage > F-Chat.Horizon-linux-x86_64.AppImage";
      music = "mpv --shuffle --af='dynaudnorm=f=250:g=15:c=1' ~/Music";
    };

    interactiveShellInit = ''
      # --- Functions ---
      nupdate() {
        local HOSTNAME=$(hostname)
        local FLAKE_PATH="$HOME/nixos-config"
        if [ -d "$FLAKE_PATH" ]; then
          sudo nixos-rebuild switch --flake "$FLAKE_PATH"#"$HOSTNAME" -v
        fi
      }

      quarter() {
        local filename="$1"
        magick "$filename" -crop 50%x50% +adjoin "''${filename%.*}_%d.''${filename##*.}"
      }

      quarter400px() {
        local filename="$1"
        magick "$filename" -crop 50%x50% +adjoin -resize 400x400! "''${filename%.*}_%d.''${filename##*.}"
      }

      # --- Completion & Visuals ---
      zmodload zsh/complist
      bindkey '^e' edit-command-line
      autoload -Uz edit-command-line; zle -N edit-command-line

      [ -f "$HOME/.config/fastfetch/fastfetch.sh" ] && "$HOME/.config/fastfetch/fastfetch.sh"
    '';
  };

  # 2. Global Environment Variables
  environment.sessionVariables = {
    # --- XDG Base Directories ---
    XDG_CACHE_HOME  = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME   = "$HOME/.local/share";
    XDG_STATE_HOME  = "$HOME/.local/state";

    # --- Wayland & Graphics Fixes ---
    GDK_BACKEND                       = "wayland,x11";
    NIXOS_OZONE_WL                  = "1";
    OBS_PLATFORM                      = "wayland";
    WLR_DRM_NO_MODIFIERS      = "1";
    WLR_NO_HARDWARE_CURSORS     = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_RENDERER                    = "gles2";
    XDG_CURRENT_DESKTOP     = "sway";
    XDG_SESSION_DESKTOP      = "sway";
    XDG_SESSION_TYPE             = "wayland";

    # --- System Tools & Theming ---
    EDITOR                                 = "nano";
    GTK_THEME                           = "Moon-Burst-Theme";
    QT_QPA_PLATFORMTHEME   = "qt6ct";
    TERMINAL                              = "kitty";

    # --- Development Homes ---
    CARGO_HOME                      = "$HOME/.local/share/cargo";
    DOTNET_CLI_HOME              = "$HOME/.local/share/dotnet";
    GNUPGHOME                        = "$HOME/.local/share/gnupg";
    GOPATH                                = "$HOME/.local/share/go";
    GTK2_RC_FILES                     = "$HOME/.config/gtk-2.0/gtkrc";
    NPM_CONFIG_CACHE            = "$HOME/.cache/npm";
    NPM_CONFIG_INIT_MODULE  = "$HOME/.config/npm/config/npm-init.js";
    PASSWORD_STORE_DIR        = "$HOME/.local/share/pass";
    RUSTUP_HOME                       = "$HOME/.local/share/rustup";
  };

  users.defaultUserShell = pkgs.zsh;

  # 3. ZSH PROMPT
  programs.zsh.promptInit = ''
    autoload -Uz colors && colors
    PROMPT="%{$fg[yellow]%}[%D{%T}] %{$fg[blue]%}%n@%m: %{$fg[green]%}%~%{$reset_color%} $"
  '';
}
