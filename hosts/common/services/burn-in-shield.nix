{ config, pkgs, ... }:

let
  # --- Burn-In Shield Minutely Micro-Shifter ---
  # Anchors tightly to neutral 6500K daylight and micro-wiggles the hardware temperature
  # every 60 seconds to disrupt pixel voltage memory without flashing your screen.
  burnInShield = pkgs.writeShellScriptBin "burn-in-shield" ''
    export PATH="${pkgs.gammastep}/bin:${pkgs.procps}/bin:${pkgs.systemd}/bin:$PATH"

    # Simple Toggle Action
    if [ "''${1:-}" = "stop" ]; then
        echo "Stopping Burn-In Shield..."
        pkill gammastep || true
        gammastep -x
        exit 0
    fi

    # --- SOURCING VIA LOGINCTL ---
    ACTIVE_SESSION=$(loginctl list-sessions | grep "$USER" | awk '{print $1}' | head -n1 || echo "")
    if [ -n "$ACTIVE_SESSION" ]; then
        export WAYLAND_DISPLAY=$(systemctl --user show-environment | grep "^WAYLAND_DISPLAY=" | cut -d= -f2- || echo "")
        if [ -z "$WAYLAND_DISPLAY" ]; then
            SESSION_PID=$(loginctl show-session "$ACTIVE_SESSION" -p Leader --value)
            export WAYLAND_DISPLAY=$(grep -z '^WAYLAND_DISPLAY=' /proc/"$SESSION_PID"/environ | cut -d= -f2- | tr -d '\0' || echo "")
        fi
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        echo "Burn-In Shield mapped to seat connection: $WAYLAND_DISPLAY"
    fi

    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        export WAYLAND_DISPLAY="wayland-0"
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi

    echo "Burn-In Shield Active. Minutely unnoticeable micro-shifting enabled..."

    # Infinite loop that calculates an unnoticeable hardware deviation step every minute
    while true; do
        CURRENT_MIN=$(date +%M)
        CYCLE=$(( 10#$CURRENT_MIN % 3 ))

        case $CYCLE in
            0) TARGET_TEMP=6400 ;; # Micro-warm shift (Unnoticeable)
            1) TARGET_TEMP=6500 ;; # Neutral stock daylight
            2) TARGET_TEMP=6600 ;; # Micro-cool shift (Unnoticeable)
        esac

        # Clear the active task process and inject the fresh micro-temperature target
        pkill gammastep || true
        gammastep -O "$TARGET_TEMP" &

        # Sleep for exactly 1 minute before stepping the crystal voltage again
        sleep 60
    done
  '';

in {
  environment.systemPackages = [ burnInShield ];

  # --- Systemd User Service Integration ---
  systemd.user.services.burn-in-shield = {
    description = "Burn-In Shield Full-Screen Pixel Recovery Service";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${burnInShield}/bin/burn-in-shield";
      ExecStop = "${burnInShield}/bin/burn-in-shield stop";
      KillMode = "control-group";
      Restart = "on-failure";
    };
  };
}
