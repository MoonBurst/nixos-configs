{ pkgs, lib, ... }:

let
  myReminders = [
    { date = "01-16"; days = 3; msg = "Luster's Birthday"; urgent = true; }
    { date = "05-24"; days = 2; msg = "Velvet's Birthday"; urgent = false; }
    { date = "05-25"; days = 2; msg = "Olive Herb's Birthday"; urgent = false; }
    { date = "05-25"; days = 2; msg = "Father's birthday"; urgent = false; }
    { date = "07-07"; days = 2; msg = "Genesis's Birthday"; urgent = true; }
    { date = "07-13"; days = 3; msg = "Sonata's Birthday"; urgent = true; }
    { date = "10-01"; days = 1; msg = "Rainbow-Dash Tumblr's Birthday"; urgent = false; }
    { date = "10-16"; days = 1; msg = "Radiant's Birthday"; urgent = false; }
    { date = "11-06"; days = 3; msg = "Chris's Birthday"; urgent = false; }
    { date = "12-05"; days = 2; msg = "Silver's Birthday"; urgent = true; }

    { date = "01-01"; days = 3; msg = "New Year's Day"; urgent = false; }
    { date = "02-14"; days = 7; msg = "Valentine's Day"; urgent = false; }
    { date = "03-17"; days = 1; msg = "St. Patrick's Day"; urgent = false; }
    { date = "04-01"; days = 1; msg = "April Fool's Day"; urgent = false; }
    { date = "07-04"; days = 1; msg = "Independence Day"; urgent = false; }
    { date = "10-31"; days = 7; msg = "Halloween"; urgent = false; }
    { date = "12-25"; days = 7; msg = "Christmas Day"; urgent = false; }
    { date = "12-31"; days = 3; msg = "New Year's Eve"; urgent = false; }
  ];

  genChecks = lib.concatMapStringsSep "\n" (r:
    "check_date \"${r.date}\" \"${r.msg}\" ${toString r.days} ${if r.urgent then "true" else "false"}"
  ) myReminders;

in {
  systemd.user.services.reminder-notification = {
    description = "Check upcoming reminders and holidays";
    wantedBy = [ "default.target" ];
    path = with pkgs; [ libnotify coreutils bash ];

    script = ''
      export DISPLAY=:0
      [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]] && export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

      YEAR=$(date +%Y)
      TODAY_FMT=$(date +%Y-%m-%d)

      echo "--- Reminder Check Started for $TODAY_FMT ---"

      check_date() {
          local m_d=$1; local msg=$2; local days=$3; local urgent=$4
          # Append year for robust date math
          local target_date="$YEAR-$m_d"

          for ((i=0; i<=days; i++)); do
              local check_day=$(date -d "$target_date -$i days" +%Y-%m-%d 2>/dev/null)
              if [[ "$check_day" == "$TODAY_FMT" ]]; then
                  echo "MATCH: $msg is in $i days!"
                  local u_flag=""
                  [[ "$urgent" == "true" ]] && u_flag="-u critical"
                  notify-send $u_flag "Reminder" "$msg is in $i days!"
              fi
          done
      }

      # --- Moving Holidays ---
      A=$((YEAR % 19)); B=$((YEAR / 100)); C=$((YEAR % 100)); D=$((B / 4)); E=$((B % 4))
      F=$(((B + 8) / 25)); G=$(((B - F + 1) / 3)); H=$(((19 * A + B - D - G + 15) % 30))
      I=$((C / 4)); K=$((C % 4)); L=$(((32 + 2 * E + 2 * I - H - K) % 7))
      M=$(((A + 11 * H + 22 * L) / 451))
      EASTER=$(printf "%02d-%02d" $(((H + L - 7 * M + 114) / 31)) $((((H + L - 7 * M + 114) % 31) + 1)))

      M1=$(date -d "$YEAR-05-01" +%u); OFF=$(((7-M1+7)%7+7))
      MOTHERS=$(date -d "$YEAR-05-01 +$OFF days" +%m-%d)

      F1=$(date -d "$YEAR-06-01" +%u); OFF=$(((7-F1+7)%7+14))
      FATHERS=$(date -d "$YEAR-06-01 +$OFF days" +%m-%d)

      T1=$(date -d "$YEAR-11-01" +%u); OFF=$(((4-T1+7)%7+21))
      THANKS=$(date -d "$YEAR-11-01 +$OFF days" +%m-%d)
      BLACKF=$(date -d "$YEAR-11-01 +$((OFF + 1)) days" +%m-%d)

      # --- Execute ---
      check_date "$EASTER" "Easter Sunday" 1 "false"
      check_date "$MOTHERS" "Mother's Day" 1 "true"
      check_date "$FATHERS" "Father's Day" 1 "true"
      check_date "$THANKS" "Thanksgiving Day" 7 "false"
      check_date "$BLACKF" "Black Friday" 0 "false"

      ${genChecks}
      echo "--- Reminder Check Complete ---"
    '';

    serviceConfig.Type = "oneshot";
  };

  systemd.user.timers.reminder-notification = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "4h";
      Persistent = true;
    };
  };
}
