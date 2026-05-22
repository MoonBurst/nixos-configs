import QtQuick
import Quickshell.Io

import Theme

Rectangle {
    id: gpuBox

    // Sovereign sizing rules restore visual visibility matching your bar grid
    width: 280
    height: 35
    radius: 10
    border.width: 3

    // Direct memory lookups pointing straight to your immutable compiled Nix-Store colors
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property string gpuDisplayText: "<font color='" + ((typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C : "green") + "'>GPU:</font> --%  --°C  --W"

    property int tempWarn: 76
    property int tempCrit: 90
    property int usageWarn: 50
    property int usageCrit: 80
    property int powerWarn: 250
    property int powerCrit: 300

    function formatValue(value, isNaNStr) {
        if (isNaN(value)) {
            return "&nbsp;".repeat(3 - isNaNStr.length) + isNaNStr;
        }
        let numStr = String(Math.round(value));
        if (numStr.length >= 3) return numStr;
        return "&nbsp;".repeat(3 - numStr.length) + numStr;
    }

    function updateGpuDisplay(usage, temp, power) {
        // Secure validation checks against our global singleton namespace variables
        const normalColor   = (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05.toString() : "yellow";
        const greenColor    = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C.toString() : "green";
        const warningColor  = (typeof Theme !== 'undefined' && Theme.base0A !== undefined) ? Theme.base0A.toString() : "orange";
        const criticalColor = (typeof Theme !== 'undefined' && Theme.base08 !== undefined) ? Theme.base08.toString() : "red";

        let valueColor = normalColor;

        let usageStr = formatValue(usage, "--");
        let tempStr = formatValue(temp, "--");
        let powerStr = formatValue(power, "--");

        let numbersText = usageStr + "%&nbsp;&nbsp;" +
        tempStr + "°C&nbsp;&nbsp;" +
        powerStr + "W";

        if (!isNaN(usage) && !isNaN(temp) && !isNaN(power)) {
            let isCritical = (temp >= tempCrit) || (usage >= usageCrit) || (power >= powerCrit);
            let isWarning = (temp >= tempWarn) || (usage >= usageWarn) || (power >= powerWarn);

            if (isCritical) {
                valueColor = criticalColor;
            } else if (isWarning) {
                valueColor = warningColor;
            }
        }

        gpuDisplayText = "<font color='" + greenColor + "'>GPU:</font>&nbsp;" +
        "<font color='" + valueColor + "'>" + numbersText + "</font>";
    }

    Process {
        id: gpuStatsProc
        running: true
        command: ["sh", "-c", "rocm-smi -a | awk 'BEGIN {U=-1; T=-1; P=-1} /GPU use \\(%\\)/ {U=$NF} /Temperature \\(Sensor junction\\)/ {T=$NF} /Average Graphics Package Power \\(W\\)/ {P=$NF} END { print U; print T; print P }'"]

        property int lineNum: 0
        property var parsedUsage: NaN
        property var parsedTemp: NaN
        property var parsedPower: NaN

        onRunningChanged: {
            if (running) {
                lineNum = 0;
                parsedUsage = NaN;
                parsedTemp = NaN;
                parsedPower = NaN;
            }
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "") return;
                gpuStatsProc.lineNum++;
                if (gpuStatsProc.lineNum === 1) {
                    let val = parseInt(data, 10);
                    gpuStatsProc.parsedUsage = (val === -1) ? NaN : val;
                } else if (gpuStatsProc.lineNum === 2) {
                    let val = parseFloat(data);
                    gpuStatsProc.parsedTemp = (val === -1) ? NaN : val;
                } else if (gpuStatsProc.lineNum === 3) {
                    let val = parseFloat(data);
                    gpuStatsProc.parsedPower = (val === -1) ? NaN : val;
                    updateGpuDisplay(gpuStatsProc.parsedUsage, gpuStatsProc.parsedTemp, gpuStatsProc.parsedPower);
                    gpuStatsProc.lineNum = 0;
                }
            }
        }
    }

    Text {
        id: gpuText
        anchors.fill: parent
        anchors.margins: 5
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: gpuDisplayText
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            gpuStatsProc.running = false;
            gpuStatsProc.running = true;
        }
    }
}
