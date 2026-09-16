{ pkgs ? import <nixpkgs> {} }:

let
  steamChecker = pkgs.writeShellScriptBin "steam-check" ''
    set -euo pipefail

    # ---- CONFIGURATION ----
    # Set your minimum discount percentage target (e.g., 80 means 80% off or better)
    MIN_DISCOUNT=50

    # Target file located in your user home folder
    URL_FILE="$HOME/steamsales.txt"

    # Cooldown timer in seconds between API requests to protect against rate limits
    COOLDOWN_DELAY=2
    # -----------------------

    # Check if the target file actually exists
    if [ ! -f "$URL_FILE" ]; then
      echo "❌ Error: File '$URL_FILE' not found!"
      echo "Please create a text file at '$URL_FILE' and paste your Steam URLs into it."
      exit 1
    fi

    echo "Scanning Steam for discounts >= $MIN_DISCOUNT% using list from $URL_FILE..."
    echo "=========================================================================="

    FIRST_RUN=true

    # Read the file line by line, skipping empty lines and lines starting with '#'
    while IFS= read -r URL || [ -n "$URL" ]; do
      # Clean up trailing carriage returns from Windows text editors (\r)
      URL=$(echo "$URL" | tr -d '\r' | xargs)

      [[ -z "$URL" || "$URL" =~ ^# ]] && continue

      # If this isn't the very first item, pause to respect the rate-limit cooldown
      if [ "$FIRST_RUN" = false ]; then
        echo "⏳ Waiting $COOLDOWN_DELAY seconds to respect rate limits..."
        sleep "$COOLDOWN_DELAY"
      fi
      FIRST_RUN=false

      # Extract the numerical App ID from the full URL using regex
      if [[ "$URL" =~ \/app\/([0-9]+) ]]; then
        APP_ID="''${BASH_REMATCH[1]}"
      else
        echo "❌ Could not parse App ID from line: $URL"
        continue
      fi

      # Fetch store data from the official Steam storefront API
      RESPONSE=$(curl -s "https://steampowered.com")

      # Verify the API request was successful for this ID
      SUCCESS=$(echo "$RESPONSE" | jq -r ".\"$APP_ID\".success" 2>/dev/null)

      if [ "$SUCCESS" != "true" ]; then
        echo "❌ Could not fetch data for App ID: $APP_ID (Check if URL is valid)"
        continue
      fi

      DATA=$(echo "$RESPONSE" | jq -r ".\"$APP_ID\".data")
      GAME_NAME=$(echo "$DATA" | jq -r ".name")
      IS_FREE=$(echo "$DATA" | jq -r ".is_free")

      if [ "$IS_FREE" == "true" ]; then
        echo "🎉 $GAME_NAME is FREE!"
        notify-send -u critical "Steam Sale Alert!" "🎉 $GAME_NAME is completely FREE!"
        continue
      fi

      PRICE_OVERVIEW=$(echo "$DATA" | jq -r ".price_overview // empty")

      if [ -z "$PRICE_OVERVIEW" ]; then
        echo "➖ $GAME_NAME has no pricing information available."
        continue
      fi

      DISCOUNT=$(echo "$PRICE_OVERVIEW" | jq -r ".discount_percent")
      CURRENT_PRICE=$(echo "$PRICE_OVERVIEW" | jq -r ".final_formatted")
      INITIAL_PRICE=$(echo "$PRICE_OVERVIEW" | jq -r ".initial_formatted")

      if [ "$DISCOUNT" -ge "$MIN_DISCOUNT" ]; then
        echo "🔥 MATCH: $GAME_NAME is $DISCOUNT% OFF!"
        echo "   Price: $INITIAL_PRICE -> $CURRENT_PRICE"
        echo "   Link:  https://steampowered.com"
        echo ""

        # Send native desktop notification via libnotify
        notify-send -u normal "Steam Discount Match!" "🔥 $GAME_NAME is $DISCOUNT% OFF!\nPrice drops to $CURRENT_PRICE"
      else
        echo "⏳ $GAME_NAME is only $DISCOUNT% off ($CURRENT_PRICE). Skipping."
      fi
    done < "$URL_FILE"

    echo "=========================================================================="
    echo "✅ Scan complete!"
  '';
in
pkgs.mkShell {
  # Added pkgs.libnotify so notify-send is fully available in the sandbox environment
  buildInputs = [ steamChecker pkgs.curl pkgs.jq pkgs.libnotify ];

  shellHook = ''
    echo "Steam Checker environment loaded with desktop notifications!"
    echo "1. Make sure you create a 'steamsales.txt' file in your home directory (~/)"
    echo "2. Run 'steam-check' to scan your list."
  '';
}
