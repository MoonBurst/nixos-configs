// GameSentinel.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: gameSentinel

    property bool isGaming: false
    property bool isStormHold: false
    property bool autoPausedSync: false

    // Dedicated Kill Process
    Process {
        id: pauseProc
        command: ["/run/current-system/sw/bin/sudo", "-n", "/run/current-system/sw/bin/game-sync-pause"]
    }

    // Dedicated Resume Process
    Process {
        id: resumeProc
        command: ["/run/current-system/sw/bin/sudo", "-n", "/run/current-system/sw/bin/game-sync-resume"]
    }

    Timer {
        interval: 2500; running: true; repeat: true
        onTriggered: gamingProcess.running = true
    }

    Process {
        id: gamingProcess
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "CONFIG_DIR=\"$HOME/.config/quickshell\"; " +
            "GAMES_FILE=\"$CONFIG_DIR/games_list.json\"; " +
            "IGNORED_FILE=\"$CONFIG_DIR/games_ignored.json\"; " +
            "mkdir -p \"$CONFIG_DIR\"; " +
            "[ ! -f \"$GAMES_FILE\" ] && echo '[\"Overwatch.exe\",\"MapleStory\",\"MapleStory.exe\"]' > \"$GAMES_FILE\"; " +
            "[ ! -f \"$IGNORED_FILE\" ] && echo '[]' > \"$IGNORED_FILE\"; " +

            "IS_GAME=0; " +
            "for game in $(jq -r '.[]' \"$GAMES_FILE\" 2>/dev/null); do " +
            "  if pgrep -x \"$game\" >/dev/null 2>&1; then " +
            "    IS_GAME=1; break; " +
            "  fi; " +
            "done; " +

            "NEW_CANDIDATE=\"\"; " +
            "if [ \"$IS_GAME\" -eq 0 ]; then " +
            "  for pid in $(pgrep -x 'wine64-preloader' || pgrep -x 'wine-preloader' 2>/dev/null); do " +
            "    COMM=$(cat /proc/$pid/comm 2>/dev/null); " +
            "    if [[ -n \"$COMM\" && ! \"$COMM\" =~ (wineserver|explorer|services|svchost|steamwebhelper|CrashMailer|crash|agent) ]]; then " +
            "      IN_GAMES=$(jq --arg c \"$COMM\" 'index($c)' \"$GAMES_FILE\" 2>/dev/null); " +
            "      IN_IGNORED=$(jq --arg c \"$COMM\" 'index($c)' \"$IGNORED_FILE\" 2>/dev/null); " +
            "      if [ \"$IN_GAMES\" = \"null\" ] && [ \"$IN_IGNORED\" = \"null\" ]; then " +
            "        NEW_CANDIDATE=\"$COMM\"; break; " +
            "      fi; " +
            "    fi; " +
            "  done; " +
            "fi; " +

            "if [ -n \"$NEW_CANDIDATE\" ]; then " +
            "  ( ACTION=$(notify-send -a \"Gaming Sentinel\" -u normal -i \"applications-games\" \"New Game Detected\" \"Add '$NEW_CANDIDATE' to Gaming Sentinel list?\" --action=add=\"Add Game\" --action=ignore=\"Ignore\"); " +
            "    if [ \"$ACTION\" = \"add\" ]; then " +
            "      jq --arg c \"$NEW_CANDIDATE\" '. + [$c] | unique' \"$GAMES_FILE\" > \"$GAMES_FILE.tmp\" && mv \"$GAMES_FILE.tmp\" \"$GAMES_FILE\"; " +
            "    else " +
            "      jq --arg c \"$NEW_CANDIDATE\" '. + [$c] | unique' \"$IGNORED_FILE\" > \"$IGNORED_FILE.tmp\" && mv \"$IGNORED_FILE.tmp\" \"$IGNORED_FILE\"; " +
            "    fi ) & " +
            "fi; " +

            // Check if severe outage storm flag is present in memory bus
            "STORM_ACTIVE=0; [ -f /dev/shm/weather-storm-active.txt ] && STORM_ACTIVE=1; " +
            "echo '{\"gaming\": '\"$([ \"$IS_GAME\" -eq 1 ] && echo true || echo false)\"', \"storm\": '\"$([ \"$STORM_ACTIVE\" -eq 1 ] && echo true || echo false)\"'}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const g = JSON.parse(data.trim());
                    let wasHeld = (gameSentinel.isGaming || gameSentinel.isStormHold);
                    gameSentinel.isGaming = (g.gaming === true);
                    gameSentinel.isStormHold = (g.storm === true);

                    let shouldHold = (gameSentinel.isGaming || gameSentinel.isStormHold);

                    // 1. ENGAGE HOLD (Fires immediately if game launches OR severe storm hits)
                    if (!wasHeld && shouldHold) {
                        gameSentinel.autoPausedSync = true;
                        pauseProc.running = false;
                        pauseProc.running = true;
                    }
                    // 2. DISENGAGE HOLD (Only resumes when BOTH game is closed AND storm has passed)
                    else if (wasHeld && !shouldHold && gameSentinel.autoPausedSync) {
                        gameSentinel.autoPausedSync = false;
                        resumeProc.running = false;
                        resumeProc.running = true;
                    }
                } catch (e) {}
            }
        }
    }
}
