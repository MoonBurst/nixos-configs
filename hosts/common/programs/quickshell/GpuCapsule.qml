import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: gpuBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    
    width: 320
    height: Theme.capsuleHeight

    property string gpuDisplayText: "GPU: Fetching..."

    Process {
        id: gpuProc
        running: true
        command: [
            "sh", "-c",
            "D=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n1); " +
            "if [ -z \"$D\" ] || [ ! -d \"$D\" ]; then echo \"0|0|0|1|0\" && exit 0; fi; " +
            "H_DIR=$(ls -d $D/hwmon/hwmon* 2>/dev/null | head -n1); " +
            "if [ -z \"$H_DIR\" ]; then T=0; P=0; else " +
            "  T=$(cat \"$H_DIR/temp1_input\" 2>/dev/null || echo 0); T=$((T / 1000)); " +
            "  P=$(cat \"$H_DIR/power1_average\" 2>/dev/null || echo 0); P=$((P / 1000000)); " +
            "fi; " +
            "U=$(cat \"$D/gpu_busy_percent\" 2>/dev/null || echo 0); " +
            "VT=$(cat \"$D/mem_info_vram_total\" 2>/dev/null || echo 0); " +
            "VU=$(cat \"$D/mem_info_vram_used\" 2>/dev/null || echo 0); " +
            "echo \"$T|$U|$P|$VT|$VU\""
        ]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var s = data.trim().split("|");
                if (s.length < 5) return;
                
                var t = parseInt(s[0], 10);
                var u = parseInt(s[1], 10);
                var p = parseInt(s[2], 10);
                var vt = parseFloat(s[3]);
                var vu = parseFloat(s[4]);
                
                var tCol = t > 90 ? '#ff0000' : (t > 76 ? '#ffa500' : '#00FF00');
                var uCol = u > 80 ? '#ff0000' : (u > 50 ? '#ffa500' : '#00FF00');
                var pCol = p > 300 ? '#ff0000' : (p > 150 ? '#ffa500' : '#00FF00');
                
                var vrStr = "20 GiB", vCol = '#00FF00';
                if (vt > 0) {
                    vrStr = Math.floor((vt - vu) / 1073741824) + " GiB";
                    var pct = (vu * 100 / vt);
                    vCol = pct > 75 ? '#ff0000' : (pct > 50 ? '#ffa500' : '#00FF00');
                } else {
                    vrStr = "20 GiB";
                }
                
                var lblCol = (tCol==='#ff0000'||uCol==='#ff0000'||pCol==='#ff0000'||vCol==='#ff0000') ? '#ff0000' : 
                             ((tCol==='#ffa500'||uCol==='#ffa500'||pCol==='#ffa500'||vCol==='#ffa500') ? '#ffa500' : '#00FF00');
                             
                var pad = (val) => {
                    var numStr = String(val);
                    if (val < 10) {
                        return "<font color='transparent'>00</font>" + numStr;
                    } else if (val < 100) {
                        return "<font color='transparent'>0</font>" + numStr;
                    }
                    return numStr;
                };

                gpuBox.gpuDisplayText = "<font color='" + lblCol + "'>GPU:</font> " +
                                        "<font color='" + tCol + "'>" + String(t).padStart(3, ' ') + "°C</font> " +
                                        "<font color='" + uCol + "'>" + pad(u) + "%</font> " +
                                        "<font color='" + pCol + "'>" + pad(p) + "W</font> " +
                                        "<font color='" + vCol + "'>VRAM: " + vrStr + "</font>";
            }
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: gpuBox.gpuDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }
    
    Timer { 
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            gpuProc.running = false;
            gpuProc.running = true;
        }
    }
}
