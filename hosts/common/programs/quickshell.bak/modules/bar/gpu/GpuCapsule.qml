import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"
import "../common"

Item {
    id: gpuBox
    property var barWindow: null
    property string moduleName: "gpu"
    property bool pinTooltip: false
    property string searchQuery: ""

    property var detectedGpus: (shell && shell.settingsManager && shell.settingsManager.discoveredGpus.length > 0)
        ? shell.settingsManager.discoveredGpus : []
    property int selectedGpuIndex: 0
    readonly property var currentGpu: (detectedGpus.length > selectedGpuIndex) ? detectedGpus[selectedGpuIndex] : null
    readonly property bool isNvidia: (currentGpu && currentGpu.vendor === "10de") || (currentGpu && currentGpu.name && currentGpu.name.toLowerCase().indexOf("nvidia") !== -1)

    property int tooltipHeight: 420
    property int tooltipCollapsedWidth: 275
    property int tooltipExpandedWidth: 520
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: (shell && shell.theme) ? shell.theme.slantWidth : 12

    property string gpuUsageRaw: "0"
    property string gpuTempRaw: "0"
    property string gpuPowerRaw: "0"
    property string gpuVramFreeRaw: "0"
    property string topGpuProcessesText: "Loading GPU processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topGpuProcessesText.split("\n").filter(line => line.trim() !== "")
    readonly property var filteredProcessLinesArray: {
        if (searchQuery.trim() === "") return processLinesArray;
        var q = searchQuery.trim().toLowerCase();
        return processLinesArray.filter(line => line.toLowerCase().indexOf(q) !== -1);
    }

    implicitWidth: Math.max(260, gpuText.implicitWidth + bg.leftPadding + bg.rightPadding + 28)
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight
        slantWidth: gpuBox.slantWidth
    }

    // Direct multi-vendor hardware reader (Nvidia, AMD, Intel)
    Process {
        id: gpuStatsProc
        running: true
        command: [
            "sh", "-c",
            'card_id="$1"; ven="$2"; is_nv="$3"; ' +
            'gpu_idx=$(echo "$card_id" | tr -dc "0-9"); [ -z "$gpu_idx" ] && gpu_idx="0"; ' +
            'if command -v nvidia-smi >/dev/null 2>&1 && ([ "$is_nv" = "1" ] || [ "$ven" = "10de" ] || echo "$card_id" | grep -qi "nvidia"); then ' +
            '  nv_out=$(nvidia-smi -i "$gpu_idx" --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.free --format=csv,noheader,nounits 2>/dev/null | head -n 1); ' +
            '  if [ -n "$nv_out" ]; then ' +
            '    echo "$nv_out" | awk -F, \'{usage=int($1); temp=int($2); pwr=int($3); vram=int($4/1024); printf "%d:%d:%d:%d\\n", usage, temp, pwr, vram}\'; exit 0; ' +
            '  fi; ' +
            'fi; ' +
            'card_dir="/sys/class/drm/$card_id/device"; ' +
            '[ ! -d "$card_dir" ] && echo "0:0:0:0" && exit 0; ' +
            'usage=$(cat "$card_dir/gpu_busy_percent" 2>/dev/null | tr -dc "0-9"); [ -z "$usage" ] && usage="0"; ' +
            'temp=$(awk \'{print int($1/1000); exit}\' "$card_dir/hwmon"/hwmon*/temp*_input 2>/dev/null || echo "0"); ' +
            'power=$(awk \'{print int($1/1000000); exit}\' "$card_dir/hwmon"/hwmon*/power1_* 2>/dev/null || echo "0"); ' +
            'total=$(cat "$card_dir/mem_info_vram_total" 2>/dev/null || echo "0"); ' +
            'used=$(cat "$card_dir/mem_info_vram_used" 2>/dev/null || echo "0"); ' +
            'if [ "$total" = "0" ] || [ -z "$total" ]; then ' +
            '  total=$(cat "$card_dir/mem_info_gtt_total" 2>/dev/null || echo "0"); ' +
            '  used=$(cat "$card_dir/mem_info_gtt_used" 2>/dev/null || echo "0"); ' +
            'fi; ' +
            'free_vram=$(awk -v t="$total" -v u="$used" \'BEGIN {if(t>u) printf "%.0f", (t-u)/1073741824; else print "0"}\'); ' +
            'printf "%s:%s:%s:%s\\n" "$usage" "$temp" "$power" "$free_vram"',
            "sh",
            gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0",
            gpuBox.currentGpu ? gpuBox.currentGpu.vendor : "",
            gpuBox.isNvidia ? "1" : "0"
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 4) {
                    gpuBox.gpuUsageRaw = parts[0].trim();
                    gpuBox.gpuTempRaw = parts[1].trim();
                    gpuBox.gpuPowerRaw = parts[2].trim();
                    gpuBox.gpuVramFreeRaw = parts[3].trim();
                }
            }
        }
    }

    // Process Monitor: Captures BOTH Graphics apps (games, Xwayland) and Compute apps (CUDA)
    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "python3", "-c",
            "import os, time, sys, subprocess, re\n" +
            "is_nv = sys.argv[1] == '1'\n" +
            "target = sys.argv[2]\n" +
            "results = []\n" +
            "if is_nv:\n" +
            "    try:\n" +
            "        out = subprocess.check_output(['nvidia-smi'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')\n" +
            "        in_proc = False\n" +
            "        for line in out.splitlines():\n" +
            "            if 'Processes:' in line: in_proc = True; continue\n" +
            "            if in_proc and line.startswith('|') and ('MiB' in line or 'GiB' in line):\n" +
            "                m = re.search(r'\\|\\s*\\d+\\s+(?:N/A|\\d+)\\s+(?:N/A|\\d+)\\s+(\\d+)\\s+[CG\\+]+\\s+(.*?)\\s+(\\d+)\\s*MiB', line)\n" +
            "                if m:\n" +
            "                    pid, name, mib = m.group(1), os.path.basename(m.group(2).strip()), int(m.group(3))\n" +
            "                    vstr = f'{mib/1024:3.1f}G' if mib >= 1024 else f'{mib:3d}M'\n" +
            "                    results.append(f'{pid}|{name[:12]:<12} {vstr:>5}    -  ')\n" +
            "    except Exception: pass\n" +
            "if not results and os.path.exists('/sys/class/drm'):\n" +
            "    def sample():\n" +
            "        data = {}\n" +
            "        for pid in os.listdir('/proc'):\n" +
            "            if not pid.isdigit(): continue\n" +
            "            fd_dir, fdinfo_dir = f'/proc/{pid}/fd', f'/proc/{pid}/fdinfo'\n" +
            "            try:\n" +
            "                p_engine, p_vram, has_target = 0, 0, False\n" +
            "                for fd in os.listdir(fd_dir):\n" +
            "                    try:\n" +
            "                        if target in os.readlink(f'{fd_dir}/{fd}'):\n" +
            "                            has_target = True\n" +
            "                            with open(f'{fdinfo_dir}/{fd}', 'r') as f:\n" +
            "                                for line in f:\n" +
            "                                    if line.startswith('drm-engine-gfx:') or line.startswith('drm-engine-compute:'):\n" +
            "                                        p_engine += int(line.split()[1])\n" +
            "                                    elif line.startswith('drm-total-vram:') or line.startswith('drm-resident-vram:'):\n" +
            "                                        v = int(line.split()[1])\n" +
            "                                        if 'KiB' in line: v *= 1024\n" +
            "                                        p_vram = max(p_vram, v)\n" +
            "                    except Exception: continue\n" +
            "                if has_target: data[pid] = (p_engine, p_vram)\n" +
            "            except Exception: continue\n" +
            "        return data\n" +
            "    s1 = sample(); time.sleep(0.12); s2 = sample()\n" +
            "    for pid, (e2, vram) in s2.items():\n" +
            "        e1 = s1.get(pid, (e2, 0))[0]\n" +
            "        pct = (max(0, e2 - e1) / 120000000.0) * 100.0\n" +
            "        if pct < 0.1 and vram == 0: continue\n" +
            "        try:\n" +
            "            with open(f'/proc/{pid}/comm', 'r') as f: comm = f.read().strip()\n" +
            "        except: comm = 'unknown'\n" +
            "        mib = vram / (1024 * 1024)\n" +
            "        vstr = f'{mib/1024:3.1f}G' if mib >= 1024 else (f'{int(mib):3d}M' if mib > 0 else '   - ')\n" +
            "        results.append(f'{pid}|{comm[:12]:<12} {vstr:>5} {pct:4.1f}%')\n" +
            "print('\\n'.join(results[:10]) if results else 'No active GPU clients')",
            gpuBox.isNvidia ? "1" : "0",
            (gpuBox.currentGpu && gpuBox.currentGpu.render) ? gpuBox.currentGpu.render : "renderD128"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") gpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            gpuBox.topGpuProcessesText = gpuBox.textAccumulatorBuffer.trim() !== "" ? gpuBox.textAccumulatorBuffer.trim() : "No active GPU clients";
        }
    }

    Timer {
        id: killRefreshTimer
        interval: 300; repeat: false
        onTriggered: {
            gpuBox.textAccumulatorBuffer = "";
            gpuProcFetcher.running = true;
        }
    }

    Text {
        id: gpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 6
        anchors.rightMargin: bg.rightPadding + 6
        anchors.topMargin: 2; anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
        font.pixelSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
        font.bold: true
        color: (shell && shell.theme) ? shell.theme.base05 : "yellow"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        clip: true

        text: {
            const usageVal = parseInt(gpuBox.gpuUsageRaw) || 0;
            const currentTemp = parseInt(gpuBox.gpuTempRaw) || 0;
            const currentPower = parseInt(gpuBox.gpuPowerRaw) || 0;
            const currentFreeVram = parseInt(gpuBox.gpuVramFreeRaw) || 0;
            const cardId = gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0";

            const _rev = (shell && shell.settingsManager) ? shell.settingsManager.gpuThresholdRevision : 0;
            const tDanger = (shell && shell.settingsManager) ? shell.settingsManager.getGpuTempDanger(cardId) : 80;
            const tWarn = (shell && shell.settingsManager) ? shell.settingsManager.getGpuTempWarn(cardId) : 70;
            const vDanger = (shell && shell.settingsManager) ? shell.settingsManager.getGpuVramDanger(cardId) : 2;
            const vWarn = (shell && shell.settingsManager) ? shell.settingsManager.getGpuVramWarn(cardId) : 4;

            let tempColor = ((shell && shell.theme) ? shell.theme.base05 : "yellow").toString();
            if (currentTemp >= tDanger) tempColor = ((shell && shell.theme) ? shell.theme.base08 : "#ff0000").toString();
            else if (currentTemp >= tWarn) tempColor = ((shell && shell.theme) ? shell.theme.base09 : "#fe8019").toString();

            let vramColor = ((shell && shell.theme) ? shell.theme.base05 : "yellow").toString();
            if (currentFreeVram <= vDanger) vramColor = ((shell && shell.theme) ? shell.theme.base08 : "#ff0000").toString();
            else if (currentFreeVram <= vWarn) vramColor = ((shell && shell.theme) ? shell.theme.base09 : "#fe8019").toString();

            return "<font color='" + ((shell && shell.theme) ? shell.theme.base0C : "#04f100") + "'>GPU:</font> " +
                "<font color='" + ((shell && shell.theme) ? shell.theme.base05 : "yellow") + "'>" + usageVal + "%</font> " +
                "<font color='" + tempColor + "'>" + currentTemp + "°C</font> " +
                "<font color='" + ((shell && shell.theme) ? shell.theme.base05 : "yellow") + "'>" + currentPower + "W</font> " +
                "<font color='" + vramColor + "'>" + currentFreeVram + "GiB</font>";
        }
    }

    HoverHandler {
        id: gpuHoverTracker
        onHoveredChanged: {
            if (hovered && !gpuTooltip.isHovered) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            gpuBox.pinTooltip = !gpuBox.pinTooltip;
            if (gpuBox.pinTooltip) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    SlantedTooltip {
        id: gpuTooltip
        moduleItem: gpuBox
        barWindow: gpuBox.barWindow
        tooltipActive: gpuHoverTracker.hovered
        pin: gpuBox.pinTooltip

        tooltipHeight: gpuBox.tooltipHeight
        collapsedCoreWidth: gpuBox.tooltipCollapsedWidth
        expandedCoreWidth: gpuBox.tooltipExpandedWidth
        topOffset: gpuBox.tooltipTopOffset
        rightOffset: gpuBox.tooltipRightOffset
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight

        RowLayout {
            y: 16
            x: gpuTooltip.slantX(y) + 20
            spacing: 8

            Text {
                text: "GPU:"
                font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
                font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
                font.bold: true
                color: (shell && shell.theme) ? shell.theme.base05 : "yellow"
            }

            Repeater {
                model: gpuBox.detectedGpus
                delegate: Rectangle {
                    width: gpuBtnText.implicitWidth + 16; height: 24; radius: 4
                    color: gpuBox.selectedGpuIndex === index ? ((shell && shell.theme) ? shell.theme.base05 : "yellow") : ((shell && shell.theme) ? shell.theme.base02 : "#222222")
                    border.width: 1; border.color: (shell && shell.theme) ? shell.theme.base05 : "yellow"

                    Text {
                        id: gpuBtnText
                        anchors.centerIn: parent
                        text: (modelData.name || modelData.id)
                        font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
                        font.pixelSize: 11; font.bold: true
                        color: gpuBox.selectedGpuIndex === index ? ((shell && shell.theme) ? shell.theme.base00 : "black") : ((shell && shell.theme) ? shell.theme.base05 : "yellow")
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            gpuBox.selectedGpuIndex = index;
                            gpuBox.textAccumulatorBuffer = "";
                            gpuStatsProc.running = false; gpuStatsProc.running = true;
                            gpuProcFetcher.running = false; gpuProcFetcher.running = true;
                        }
                    }
                }
            }
        }

        ProcessMonitorList {
            tooltip: gpuTooltip
            startY: 100; listWidth: 345
            lines: gpuBox.filteredProcessLinesArray
            slantLeft: gpuBox.slantLeft; slantRight: gpuBox.slantRight
            onSearchModified: (q) => gpuBox.searchQuery = q
            onKillRequested: killRefreshTimer.start()
            onCloseRequested: {
                gpuBox.pinTooltip = false;
                gpuTooltip.closeTooltip();
            }
        }
    }

    Timer {
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            gpuStatsProc.running = false; gpuStatsProc.running = true;
            if ((gpuHoverTracker.hovered || gpuBox.pinTooltip) && !gpuTooltip.isHovered) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }
}
