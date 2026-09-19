{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.steamsale;

  steamCheckScript = pkgs.writeShellScript "check-steam-sales" ''
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    SALES_FILE="/home/${cfg.user}/steamsales"

    if [ ! -f "$SALES_FILE" ]; then
      exit 0
    fi

    while IFS= read -r line || [ -n "$line" ]; do
      [[ "$line" =~ ^#.*$ ]] && continue
      [[ -z "''${line// }" ]] && continue

      APP_ID=$(echo "$line" | ${pkgs.gnugrep}/bin/grep -oP '(?:app/|/)?([0-9]+)' | head -n1 | ${pkgs.gnused}/bin/sed 's/[^0-9]//g')

      if [ -z "$APP_ID" ]; then
        continue
      fi

      # Request both basic details (name) and price overview
      DATA=$(${pkgs.curl}/bin/curl -s "https://store.steampowered.com/api/appdetails?appids=$APP_ID&cc=us&filters=basic,price_overview")
      
      SUCCESS=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r ".\"$APP_ID\".success // false")
      if [ "$SUCCESS" != "true" ]; then
        continue
      fi

      # Extract the real game title!
      GAME_NAME=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r ".\"$APP_ID\".data.name // \"App $APP_ID\"")
      DISCOUNT=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r ".\"$APP_ID\".data.price_overview.discount_percent // 0")
      FINAL_PRICE=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r ".\"$APP_ID\".data.price_overview.final_formatted // \"Free\"")

      if [ "$DISCOUNT" -ge "${toString cfg.discountThreshold}" ]; then
        ${pkgs.libnotify}/bin/notify-send -u critical \
          "🔥 Steam Sale Alert!" \
          "$GAME_NAME is $DISCOUNT% off! Now $FINAL_PRICE"
      fi
    done < "$SALES_FILE"
  '';
in
{
  options.services.steamsale = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Steam Wishlist Sale Checker.";
    };

    user = mkOption {
      type = types.str;
      default = "moonburst";
      description = "Target user.";
    };

    discountThreshold = mkOption {
      type = types.int;
      default = 80;
      description = "Minimum discount percentage.";
    };

    interval = mkOption {
      type = types.str;
      default = "00/12:00:00";
      description = "Run interval.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services."steamsale-checker" = {
      description = "Check Steam Wishlist Discounts";
      serviceConfig = {
        ExecStart = "${steamCheckScript}";
        Type = "oneshot";
      };
    };

    systemd.user.timers."steamsale-checker" = {
      description = "Run Steam Sale Checker Every 12 Hours";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };
  };
}
