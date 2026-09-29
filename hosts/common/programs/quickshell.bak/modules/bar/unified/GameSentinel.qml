// GameSentinel.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: gameSentinel

    property bool isGaming: false
    property bool isStormHold: false
    property bool autoPausedSync: false

    Process {
        id: pauseProc
        command: ["sudo", "-n", "game-sync-pause"]
    }

    Process {
        id: resumeProc
        command: ["sudo", "-n", "game-sync-resume"]
    }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: gamingProcess.running = true
    }

    Process {
        id: gamingProcess
        command: [
            "bash", "-c",
            'CONFIG_DIR="$HOME/.config/quickshell"; ' +
            'GAMES_FILE="$CONFIG_DIR/games_list.json"; ' +
            'IGNORED_FILE="$CONFIG_DIR/games_ignored.json"; ' +
            'mkdir -p "$CONFIG_DIR"; ' +
            '[ ! -f "$GAMES_FILE" ] && echo \'["Overwatch.exe","MapleStory","MapleStory.exe"]\' > "$GAMES_FILE"; ' +
            '[ ! -f "$IGNORED_FILE" ] && echo \'[]\' > "$IGNORED_FILE"; ' +
            'IS_GAME=0; ' +
            'PATTERN=$(cat "$GAMES_FILE" 2>/dev/null | tr -d \'[]"\\r\\n \' | tr \',\' \'|\' | sed \'s/|*$//\'); ' +
            'if [ -n "$PATTERN" ] && pgrep -E "$PATTERN" >/dev/null 2>&1; then ' +
            '  IS_GAME=1; ' +
            'fi; ' +
            'STORM_ACTIVE=0; [ -f /dev/shm/weather-storm-active.txt ] && STORM_ACTIVE=1; ' +
            'echo "{\\"gaming\\": $([ $IS_GAME -eq 1 ] && echo true || echo false), \\"storm\\": $([ $STORM_ACTIVE -eq 1 ] && echo true || echo false)}"'
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const g = JSON.parse(data.trim());
                    let wasHeld = (gameSentinel.isGaming || gameSentinel.isStormHold);
                    gameSentinel.isGaming = (g.gaming === true);
                    gameSentinel.isStormHold = (g.storm === true);

                    let shouldHold = (gameSentinel.isGaming || gameSentinel.isStormHold);

                    if (!wasHeld && shouldHold) {
                        gameSentinel.autoPausedSync = true;
                        pauseProc.running = false;
                        pauseProc.running = true;
                    } else if (wasHeld && !shouldHold && gameSentinel.autoPausedSync) {
                        gameSentinel.autoPausedSync = false;
                        resumeProc.running = false;
                        resumeProc.running = true;
                    }
                } catch (e) {}
            }
        }
    }
}
