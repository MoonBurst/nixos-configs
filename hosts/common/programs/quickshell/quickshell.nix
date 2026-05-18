{ pkgs, config, ... }:

let
  cfgColors = config.lib.stylix.colors.withHashtag;
  base      = cfgColors.base00; # #1a1a1a
  bubble    = cfgColors.base01; # #0F0F0F
  outline   = cfgColors.base03; # #003399
  textColor = cfgColors.base05; # #F7F700
  red       = cfgColors.base08; # #FF0000
  gray0b    = cfgColors.base0B; # #545454

  # Package your memory script into an executable file inside the Nix store
  memScript = pkgs.writeScriptBin "quickshell-mem-check" ''
    #!/usr/bin/env bash
    set -euo pipefail

    RED_THRESHOLD=8
    WARN_THRESHOLD=16
    COLOR_CRITICAL="${red}" # Syncs with your Stylix red color dynamically!
    COLOR_WARNING="#FFA500"
    COLOR_SUFFICIENT="${textColor}" # Matches your default text color accent

    available_memory=$(free -g | awk '/Mem/ {print $7}')

    color="$COLOR_SUFFICIENT"
    if (( available_memory < RED_THRESHOLD )); then
        color="$COLOR_CRITICAL"
    elif (( available_memory < WARN_THRESHOLD )); then
        color="$COLOR_WARNING"
    fi

    # Format the tooltip structure clearly
    tooltip=$(ps -eo rss,comm --no-headers | awk '{mag[$2]+=$1} END {for (i in mag) print mag[i], i}' | sort -rn | awk 'NR<=10 {printf "%7d MB  %s\\n", $1/1024, $2}')

    # Output pure JSON for the QML parser engine to digest
    echo "{\"color\": \"$color\", \"text\": \"RAM: $available_memory GiB\", \"tooltip\": \"$tooltip\"}"
  '';

  myQuickshellConfig = pkgs.writeText "shell.qml" ''
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Scope {
        id: root

        // Define reactive global state properties to hold our bash script data
        property string ramText: "RAM: -- GiB"
        property string ramColor: "${textColor}"
        property string ramTooltipText: "Loading processes..."

        // Global Process controller to execute your custom memory script
        Process {
            id: ramProcess
            command: ["${memScript}/bin/quickshell-mem-check"]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        // Safely parse the JSON string emitted by the Bash echo statement
                        var data = JSON.parse(this.text.trim());
                        root.ramText = data.text;
                        root.ramColor = data.color;
                        root.ramTooltipText = data.tooltip;
                    } catch(e) {
                        console.log("Failed to parse RAM script output: " + e);
                    }
                }
            }
        }

        // Rerun the script every 5 seconds to keep metrics updated smoothly
        Timer {
            interval: 5000
            running: true
            repeat: true
            onTriggered: ramProcess.running = true
        }

        Variants {
            model: Quickshell.screens

            PanelWindow {
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: 32

                Rectangle {
                    anchors.fill: parent
                    color: "${base}"
                    border.color: "${outline}"
                    border.width: 1

                    // Left Module (Sway Bubble)
                    Rectangle {
                        id: leftBubble
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        height: 24
                        width: 60
                        radius: 4
                        color: "${bubble}"
                        border.color: "${gray0b}"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "SWAY"
                            color: "${textColor}"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    // Right Modules Container
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 12
                        spacing: 20

                        // Dynamic Script-fed Memory Module with custom hover tooltip interaction
                        Rectangle {
                            height: 24
                            width: ramDisplayLabel.width + 16
                            radius: 4
                            color: "${bubble}"
                            border.color: root.ramColor
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: ramDisplayLabel
                                anchors.centerIn: parent
                                text: root.ramText
                                color: root.ramColor
                                font.pixelSize: 12
                                font.bold: true
                            }

                            // Quickshell Mouse interaction area for showing the raw script process list
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                onEntered: {
                                    toolTipPopup.visible = true;
                                }
                                onExited: {
                                    toolTipPopup.visible = false;
                                }
                            }

                            // Floating Hover Tooltip container drawing the top 10 processes matching your layout colors
                            Rectangle {
                                id: toolTipPopup
                                visible: false
                                width: 220
                                height: 180
                                color: "${base}"
                                border.color: "${outline}"
                                border.width: 1
                                radius: 4
                                
                                // Coordinates placement directly floating beneath the module boundary
                                x: parent.width - width
                                y: parent.height + 6
                                z: 100 

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    text: "Top 10 Processes:\n" + root.ramTooltipText
                                    color: "${textColor}"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    lineHeight: 1.2
                                }
                            }
                        }

                        // System Clock Module
                        Text {
                            id: clockDisplay
                            color: "${textColor}"
                            font.pixelSize: 13
                            font.bold: true
                            text: Qt.formatDateTime(systemTime.date, "hh:mm:ss AP")

                            SystemClock {
                                id: systemTime
                                precision: SystemClock.Seconds
                            }
                        }
                    }
                }
            }
        }
    }
  '';
in {
  environment.systemPackages = [
    (builtins.getFlake "github:quickshell-mirror/quickshell").packages.x86_64-linux.default
    memScript
  ];

  environment.etc."quickshell-current-path".text = "${myQuickshellConfig}";
}
