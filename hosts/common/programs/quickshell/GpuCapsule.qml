import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: gpuBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 275
    height: Theme.capsuleHeight

    property string gpuDisplayText: "GPU: --"

    Process {
        id: gpuProc
        running: true
        command: [
            "sh", "-c",
            "O=$(rocm-smi -d 0 -a --showmeminfo VRAM 2>/dev/null || :); [ -z \"$O\" ] && echo \"0|0|0|0|0\" && exit 0; " +
            "T=$(echo \"$O\" | awk '/Temperature /{print $NF}' | head -n1 | xargs printf \"%.0f\" 2>/dev/null || echo 0); " +
            "P=$(echo \"$O\" | awk '/Power /{print $NF}' | head -n1 | xargs printf \"%.0f\" 2>/dev/null || echo 0); " +
            "U=$(echo \"$O\" | awk '/GPU use/ {print $NF}' | tr -cd '0-9' || echo 0); " +
            "VT=$(echo \"$O\" | awk '/VRAM Total Memory/{print $NF}' | tr -cd '0-9' || echo 0); " +
            "VU=$(echo \"$O\" | awk '/VRAM Total Used/{print $NF}' | tr -cd '0-9' || echo 0); " +
            "echo \"$T|$U|$P|$VT|$VU\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var s = data.trim().split("|");
                if (s.length < 5) return;
                var t = parseInt(s[0]), u = parseInt(s[1]), p = parseInt(s[2]), vt = parseInt(s[3]), vu = parseInt(s[4]);
                var tCol = t > 90 ? '#ff0000' : (t > 76 ? '#ffa500' : '#00FF00');
                var uCol = u > 80 ? '#ff0000' : (u > 50 ? '#ffa500' : '#00FF00');
                var pCol = p > 300 ? '#ff0000' : (p > 150 ? '#ffa500' : '#00FF00');
                var vrStr = "N/A", vCol = '#00FF00';
                if (vt > 0) {
                    vrStr = Math.floor((vt - vu) / 1073741824) + " GiB";
                    var pct = (vu * 100 / vt); vCol = pct > 75 ? '#ff0000' : (pct > 50 ? '#ffa500' : '#00FF00');
                }
                var lblCol = (tCol==='#ff0000'||uCol==='#ff0000'||pCol==='#ff0000'||vCol==='#ff0000') ? '#ff0000' : ((tCol==='#ffa500'||uCol==='#ffa500'||pCol==='#ffa500'||vCol==='#ffa500') ? '#ffa500' : '#00FF00');
                gpuBox.gpuDisplayText = "<font color='" + lblCol + "'>GPU:</font> <font color='" + tCol + "'>" + String(t).padStart(3, ' ') + "°C</font> <font color='" + uCol + "'>" + String(u).padStart(3, ' ') + "%</font> <font color='" + pCol + "'>" + String(p).padStart(3, ' ') + "W</font> <font color='" + vCol + "'>VRAM: " + vrStr + "</font>";
            }
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: gpuBox.gpuDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: gpuProc.running = true }
}
