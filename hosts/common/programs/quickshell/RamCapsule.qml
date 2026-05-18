import QtQuick
import QtQuick.Controls
import Quickshell

Rectangle {
    id: ramBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 120
    height: Theme.capsuleHeight

    property string ramDisplayText: "RAM: -- GiB"
    property string ramTooltipText: "Fetching process memory usage..."

    // Native JavaScript engine runs completely in-process with zero shell commands
    function updateNativeMemoryTelemetry() {
        // 1. Fetch available memory natively from the Linux kernel tree
        var xhrMem = new XMLHttpRequest();
        xhrMem.open("GET", "file:///proc/meminfo", false);
        try {
            xhrMem.send();
        } catch(e) {
            return;
        }
        
        var memText = xhrMem.responseText;
        var lines = memText.split("\n");
        var totalKb = 1, availableKb = 0;
        
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("MemTotal:")) {
                totalKb = parseInt(lines[i].replace(/[^0-9]/g, ""), 10);
            }
            if (lines[i].startsWith("MemAvailable:")) {
                availableKb = parseInt(lines[i].replace(/[^0-9]/g, ""), 10);
            }
        }
        
        var availableGiB = Math.round(availableKb / 1048576);
        var col = availableGiB < 8 ? '#FF0000' : (availableGiB < 16 ? '#FFA500' : '#00FF00');
        ramBox.ramDisplayText = "<font color='" + col + "'>RAM: " + String(availableGiB).padStart(2, ' ') + " GiB</font>";

        // 2. Scan the active /proc filesystem loop directly inside the JS engine
        var processMap = {};
        
        // Use a lightweight system task directory peek structure
        var xhrLoad = new XMLHttpRequest();
        xhrLoad.open("GET", "file:///proc", false);
        try { xhrLoad.send(); } catch(e) {}
        
        // Filter and iterate over running process IDs natively
        var procLines = xhrLoad.responseText ? xhrLoad.responseText.split("\n") : [];
        var pidCount = 0;

        for (var j = 0; j < procLines.length; j++) {
            var token = procLines[j].trim();
            if (!/^\d+$/.test(token)) continue; // Keep only numerical process ID directories
            
            pidCount++;
            if (pidCount > 250) break; // Throttle to prevent system hang caps on huge setups

            var pid = token;
            var xhrStatm = new XMLHttpRequest();
            var xhrComm = new XMLHttpRequest();
            
            xhrStatm.open("GET", "file:///proc/" + pid + "/statm", false);
            xhrComm.open("GET", "file:///proc/" + pid + "/comm", false);
            
            try {
                xhrStatm.send();
                xhrComm.send();
                
                var rssPages = parseInt(xhrStatm.responseText.split(/\s+/)[1], 10);
                var name = xhrComm.responseText.trim();
                
                if (rssPages > 0 && name !== "") {
                    // Convert native system kernel memory pages securely to Megabytes
                    var mb = (rssPages * 4) / 1024;
                    if (processMap[name]) {
                        processMap[name] += mb;
                    } else {
                        processMap[name] = mb;
                    }
                }
            } catch(e) {
                continue; // Skip processes that exit during our active fetch tick
            }
        }

        // Sort process objects natively into an array stack
        var sortedList = [];
        for (var key in processMap) {
            sortedList.push({ "name": key, "mem": processMap[key] });
        }
        sortedList.sort(function(a, b) { return b.mem - a.mem; });

        // Compile the top-10 layout table string natively
        var formattedTooltip = "Top Process Memory Usage:\n===========================\n";
        var maxRows = Math.min(sortedList.length, 10);
        for (var k = 0; k < maxRows; k++) {
            var pName = sortedList[k].name.substring(0, 15).padEnd(15, ' ');
            var pMem = sortedList[k].mem.toFixed(1).padStart(7, ' ') + " MB";
            formattedTooltip += pName + " " + pMem + "\n";
        }
        
        ramBox.ramTooltipText = formattedTooltip.trim();
    }

    HoverHandler { id: ramHover }

    ToolTip {
        visible: ramHover.hovered; delay: 100 
        contentItem: Text { text: ramBox.ramTooltipText; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 13 }
        background: Rectangle { color: Theme.colorBaseBg; border.color: "#003399"; border.width: Theme.capsuleBorderWidth; radius: 6 }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: ramBox.ramDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    // Native clock tick updates values safely in the background
    Timer { 
        interval: 4000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: ramBox.updateNativeMemoryTelemetry()
    }
}
