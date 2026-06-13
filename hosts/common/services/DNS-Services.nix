{ config, pkgs, lib, ... }:

let
  dnsOptimizerScript = pkgs.writeShellScriptBin "dns-optimizer" ''
    # DNS Providers to test
    declare -A DNS_SERVERS=(
      ["1.1.1.1"]="Cloudflare"
      ["8.8.8.8"]="Google"
      ["9.9.9.9"]="Quad9"
    )

    get_latency() {
      # Ping 3 times, timeout 2s, extract the average RTT (5th field when split by '/')
      local latency=$(ping -c 3 -W 2 "$1" 2>/dev/null | awk -F'/' '/rtt/ {print $5}')
      if [ -z "$latency" ]; then
        echo "999.9" # Fallback high latency if ping fails
      else
        echo "$latency"
      fi
    }

    echo "=== Starting DNS Latency Optimization ==="
    
    FASTEST_IP=""
    MIN_LATENCY=1000.0

    for ip in "''${!DNS_SERVERS[@]}"; do
      name="''${DNS_SERVERS[$ip]}"
      latency=$(get_latency "$ip")
      echo "Provider: $name ($ip) | Latency: $latency ms"
      
      # Floating point comparison in Bash via bc
      if (( $(echo "$latency < $MIN_LATENCY" | bc -l) )); then
        MIN_LATENCY=$latency
        FASTEST_IP=$ip
      fi
    done

    echo "Fastest DNS determined: ''${DNS_SERVERS[$FASTEST_IP]} ($FASTEST_IP) at $MIN_LATENCY ms"

    # Find active default network interface
    INTERFACE=$(ip route show | grep default | awk '{print $5}' | head -n1)
    if [ -z "$INTERFACE" ]; then
      echo "Error: No default network interface found."
      exit 1
    fi

    # Dynamically apply the change depending on the network stack active
    if systemctl is-active --quiet systemd-resolved.service; then
      echo "Applying changes via systemd-resolved on interface $INTERFACE..."
      resolvectl dns "$INTERFACE" "$FASTEST_IP"
      resolvectl flush-caches
      echo "Successfully updated systemd-resolved."
      
    elif systemctl is-active --quiet NetworkManager.service; then
      echo "Applying changes via NetworkManager on interface $INTERFACE..."
      nmcli device modify "$INTERFACE" ipv4.dns "$FASTEST_IP"
      echo "Successfully updated NetworkManager."
      
    else
      echo "Warning: Neither systemd-resolved nor NetworkManager is active. DNS cannot be safely updated at runtime."
      exit 1
    fi
  '';
in
{
  environment.systemPackages = [
    dnsOptimizerScript
    pkgs.bc
    pkgs.bind.dnsutils # Installs 'dig' for testing resolution speeds
  ];

  # 1. Systemd Service Definition with Explicit Path Dependencies
  systemd.services.dns-optimizer = {
    description = "Measure and optimize DNS resolver latency";
    
    # This imports the required binary runtimes directly into the service environment
    path = [
      pkgs.iproute2       # Provides 'ip'
      pkgs.gawk           # Provides 'awk'
      pkgs.bc             # Provides 'bc'
      pkgs.iputils        # Provides 'ping'
      pkgs.gnugrep        # Provides 'grep'
      pkgs.systemd        # Provides 'resolvectl' / 'systemctl'
      pkgs.networkmanager # Provides 'nmcli'
    ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${dnsOptimizerScript}/bin/dns-optimizer";
      After = [ "network.target" ];
    };
  };

  # 2. Systemd Timer to run the service periodically
  systemd.timers.dns-optimizer = {
    description = "Timer to run the DNS Latency Optimizer every 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";         
      OnUnitActiveSec = "15m";   
      AccuracySec = "1m";
    };
  };
}
