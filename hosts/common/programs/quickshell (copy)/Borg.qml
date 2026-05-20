import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: borgModule

    // Updated width to 125 as requested
    width: 125
    height: Theme.capsuleHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    property string statusClass: "normal"
    property string themeColor: statusClass === "critical" ? "#FF3333" : Theme.colorBaseBg
    property string themeBorderColor: statusClass === "critical" ? "#FF0000" : Theme.colorOutline

    // Default text updated to "borg is idle"
    property string statusText: "borg is idle"
    property string tooltipText: "Borg Backup is inactive."

    Process {
        id: borgScriptFetcher
        running: true

        // Inline system execution pipeline simulating your exact bash logic
        command: [
            "sh", "-c",
            "SERVICE='borgbackup-job-MoonBeauty-Offsite.service'; " +
            "if systemctl is-failed --quiet \"$SERVICE\"; then " +
            "  echo '{\"text\": \"      ERR\", \"tooltip\": \"Borg Job FAILED!\", \"class\": \"critical\"}'; " +
            "elif ! systemctl is-active --quiet \"$SERVICE\"; then " +
            "  echo ''; " +
            "else " +
            "  STATS=$(rclone rc core/stats 2>/dev/null); " +
            "  if [[ -z \"$STATS\" || \"$STATS\" == \"{}\" ]]; then " +
            "    echo '{\"text\": \"   Prep\", \"tooltip\": \"Borg is starting up...\"}'; " +
            "  else " +
            "    BYTES=$(echo \"$STATS\" | jq -r '.bytes // 0'); " +
            "    TOTAL=$(echo \"$STATS\" | jq -r '.totalBytes // 0'); " +
            "    SPEED_RAW=$(echo \"$STATS\" | jq -r '.speed // 0'); " +
            "    SPEED=$(echo \"$SPEED_RAW\" | awk '{printf \"%.1f KB/s\", $1/1024}'); " +
            "    FILE=$(echo \"$STATS\" | jq -r '.transferring[0].name // \"Syncing\"'); " +
            "    DONE_FILES=$(echo \"$STATS\" | jq -r '.transfers // 0'); " +
            "    TOTAL_FILES=$(echo \"$STATS\" | jq -r '.totalTransfers // 0'); " +
            "    if [[ \"$TOTAL\" -gt 0 ]]; then " +
            "      PERCENT=$(( 100 * BYTES / TOTAL )); " +
            "      BYTES_LEFT=$(( TOTAL - BYTES )); " +
            "      MB_LEFT=$(echo \"$BYTES_LEFT\" | awk '{printf \"%.1f MB\", $1/1024/1024}'); " +
            "    else " +
            "      PERCENT=0; " +
            "      MB_LEFT=\"Calculating...\"; " +
            "    fi; " +
            "    if [[ \"$PERCENT\" -eq 0 && $(echo \"$SPEED_RAW > 0\" | bc -l) -eq 1 ]]; then " +
            "      TEXT=\"   Sync\"; " +
            "    else " +
            "      TEXT=\"   ${PERCENT}%\"; " +
            "    fi; " +
            "    jq -n -c --arg txt \"$TEXT\" --arg p \"$PERCENT\" --arg r \"$MB_LEFT\" --arg df \"$DONE_FILES\" --arg tf \"$TOTAL_FILES\" --arg f \"$FILE\" --arg s \"$SPEED\" '{text: $txt, tooltip: \"Total Progress: \\($p)%\\nRemaining: \\($r)\\nFiles: \\($df)/\\($tf)\\nActive: \\($f)\\nSpeed: \\($s)\"}'; " +
            "  fi; " +
            "fi"
        ]

        stdout: SplitParser {
            onRead: data => {
                if (!data || data.trim() === "") {
                    // Custom idle strings applied here
                    borgModule.statusText = "Borg is idle";
                    borgModule.tooltipText = "Borg Backup is inactive.";
                    borgModule.statusClass = "normal";
                    return;
                }

                try {
                    let parsed = JSON.parse(data);
                    borgModule.statusText = parsed.text || "   Sync";
                    borgModule.tooltipText = parsed.tooltip || "";
                    borgModule.statusClass = parsed.class || "normal";
                } catch(e) {
                    console.log("Error parsing Borg JSON: " + e);
                }
            }
        }
    }

    // Interval driver loops the shell string verification engine safely every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!borgScriptFetcher.running) {
                borgScriptFetcher.running = true;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: borgModule.themeColor
        border.color: borgModule.themeBorderColor
        border.width: Theme.capsuleBorderWidth
        radius: Theme.capsuleRadius

        Text {
            anchors.centerIn: parent
            color: Theme.colorNormalText
            font.family: "monospace"
            font.pixelSize: 14 // Drop slightly to fit "borg is idle" perfectly into 125px bounds
            font.bold: true
            text: borgModule.statusText
        }

        HoverHandler { id: borgHover }
        ToolTip {
            visible: borgHover.hovered && borgModule.tooltipText !== ""
            delay: 100
            contentItem: Text {
                text: borgModule.tooltipText
                color: Theme.colorNormalText
                font.family: "monospace"
                font.pixelSize: 13
            }
            background: Rectangle {
                color: Theme.colorBaseBg
                border.color: borgModule.themeBorderColor
                border.width: Theme.capsuleBorderWidth
                radius: 6
            }
        }
    }
}
