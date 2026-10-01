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

    property var detectedGpus: (shell && shell.settingsManager && shell.settingsManager.availableGpuCards && shell.settingsManager.availableGpuCards.length > 0)
        ? shell.settingsManager.availableGpuCards
        : [{ id: "card0", vendor: "", name: "GPU 0", render: "renderD128", nv_index: "0" }, { id: "card1", vendor: "", name: "GPU 1", render: "renderD129", nv_index: "0" }]

    property int selectedGpuIndex: 0

    function cycleGpu() {
        if (detectedGpus.length <= 1) return;
        selectedGpuIndex = (selectedGpuIndex + 1) % detectedGpus.length;
        if (shell && shell.settingsManager) {
            shell.settingsManager.activeGpuCard = detectedGpus[selectedGpuIndex].id;
        }
        textAccumulatorBuffer = "";
        gpuStatsProc.running = false; gpuStatsProc.running = true;
        gpuProcFetcher.running = false; gpuProcFetcher.running = true;
    }

    Connections {
        target: shell ? shell.settingsManager : null
        function onActiveGpuCardChanged() {
            if (!shell || !shell.settingsManager) return;
            var target = shell.settingsManager.activeGpuCard;
            for (var i = 0; i < gpuBox.detectedGpus.length; i++) {
                if (gpuBox.detectedGpus[i].id === target) {
                    gpuBox.selectedGpuIndex = i;
                    break;
                }
            }
        }
    }

    readonly property var currentGpu: (detectedGpus && detectedGpus.length > selectedGpuIndex) ? detectedGpus[selectedGpuIndex] : null
    readonly property bool isNvidia: (currentGpu && currentGpu.vendor === "10de") || (currentGpu && currentGpu.name && currentGpu.name.toLowerCase().indexOf("nvidia") !== -1)
    readonly property string nvTargetIndex: (currentGpu && currentGpu.nv_index !== undefined) ? currentGpu.nv_index : "0"

    property int tooltipHeight: 440
    property int tooltipCollapsedWidth: 140
    property int tooltipExpandedWidth: 520
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(gpuBox.moduleName, "right") === "right" ? "Right" : "Left") : "Right"
    property string slantRight: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(gpuBox.moduleName, "right") === "right" ? "Right" : "Left") : "Right"
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

    Process {
        id: gpuStatsProc
        running: true
        command: [
            "sh", "-c",
            'card_id="$1"; ven="$2"; is_nv="$3"; nv_idx="$4"; ' +
            '[ -z "$nv_idx" ] && nv_idx="0"; ' +
            'if command -v nvidia-smi >/dev/null 2>&1 && ([ "$is_nv" = "1" ] || [ "$ven" = "10de" ]); then ' +
            '  nv_out=$(nvidia-smi -i "$nv_idx" --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.free --format=csv,noheader,nounits 2>/dev/null | head -n 1); ' +
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
            gpuBox.currentGpu ? (gpuBox.currentGpu.vendor || "") : "",
            gpuBox.isNvidia ? "1" : "0",
            gpuBox.nvTargetIndex
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

    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "python3", "-c",
            "import os, time, sys, subprocess, glob\n" +
            "card_id = sys.argv[1]\n" +
            "vendor = sys.argv[2]\n" +
            "is_nv = sys.argv[3] == '1'\n" +
            "nv_idx = sys.argv[4]\n" +
            "results = []\n" +
            "if is_nv or vendor == '10de':\n" +
            "    try:\n" +
            "        out = subprocess.check_output(['nvidia-smi', '-i', nv_idx, '--query-compute-apps=pid,process_name,used_memory', '--format=csv,noheader,nounits'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')\n" +
            "        out += subprocess.check_output(['nvidia-smi', '-i', nv_idx, '--query-graphics-apps=pid,process_name,used_memory', '--format=csv,noheader,nounits'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')\n" +
            "        seen_pids = set()\n" +
            "        for line in out.strip().splitlines():\n" +
            "            p = [x.strip() for x in line.split(',')]\n" +
            "            if len(p) >= 3 and p[0] not in seen_pids:\n" +
            "                seen_pids.add(p[0])\n" +
            "                pid, name, mib = p[0], os.path.basename(p[1]), int(float(p[2]))\n" +
            "                vstr = f'{mib/1024:3.1f}G' if mib >= 1024 else f'{mib:3d}M'\n" +
            "                results.append((mib, f'{pid}|{name[:12]:<12} {vstr:>5}    -  '))\n" +
            "    except: pass\n" +
            "if not results:\n" +
            "    drm_nodes = set([card_id])\n" +
            "    dev_path = f'/sys/class/drm/{card_id}/device/drm'\n" +
            "    if os.path.isdir(dev_path):\n" +
            "        for n in os.listdir(dev_path): drm_nodes.add(n)\n" +
            "    def scan_clients():\n" +
            "        data = {}\n" +
            "        for pid in os.listdir('/proc'):\n" +
            "            if not pid.isdigit(): continue\n" +
            "            fd_dir, fdinfo_dir = f'/proc/{pid}/fd', f'/proc/{pid}/fdinfo'\n" +
            "            try:\n" +
            "                p_engine, p_vram, matched = 0, 0, False\n" +
            "                for fd in os.listdir(fd_dir):\n" +
            "                    try:\n" +
            "                        link = os.readlink(f'{fd_dir}/{fd}')\n" +
            "                        if any(n in link for n in drm_nodes):\n" +
            "                            matched = True\n" +
            "                            try:\n" +
            "                                with open(f'{fdinfo_dir}/{fd}', 'r') as f:\n" +
            "                                    for l in f:\n" +
            "                                        if l.startswith(('drm-engine-gfx:', 'drm-engine-compute:')):\n" +
            "                                            p_engine += int(l.split()[1])\n" +
            "                                        elif l.startswith(('drm-total-vram:', 'drm-resident-vram:', 'drm-memory-vram:')):\n" +
            "                                            v = int(l.split()[1])\n" +
            "                                            if 'KiB' in l: v *= 1024\n" +
            "                                            p_vram = max(p_vram, v)\n" +
            "                            except: pass\n" +
            "                    except: continue\n" +
            "                if matched: data[pid] = (p_engine, p_vram)\n" +
            "            except: continue\n" +
            "        return data\n" +
            "    s1 = scan_clients(); time.sleep(0.1); s2 = scan_clients()\n" +
            "    for pid, (e2, vram) in s2.items():\n" +
            "        e1 = s1.get(pid, (e2, 0))[0]\n" +
            "        pct = (max(0, e2 - e1) / 100000000.0) * 100.0\n" +
            "        mib = int(vram / (1024 * 1024))\n" +
            "        if mib <= 0 and pct < 0.1: continue\n" +
            "        try: comm = open(f'/proc/{pid}/comm').read().strip()\n" +
            "        except: comm = 'unknown'\n" +
            "        vstr = f'{mib/1024:3.1f}G' if mib >= 1024 else f'{mib:3d}M'\n" +
            "        results.append((mib, f'{pid}|{comm[:12]:<12} {vstr:>5} {pct:4.1f}%'))\n" +
            "results.sort(key=lambda x: x[0], reverse=True)\n" +
            "lines = [r[1] for r in results[:10]]\n" +
            "print('\\n'.join(lines) if lines else 'No active clients on this GPU')",
            gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0",
            gpuBox.currentGpu ? (gpuBox.currentGpu.vendor || "") : "",
            gpuBox.isNvidia ? "1" : "0",
            gpuBox.nvTargetIndex
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") gpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            gpuBox.topGpuProcessesText = gpuBox.textAccumulatorBuffer.trim() !== "" ? gpuBox.textAccumulatorBuffer.trim() : "No active clients on this GPU";
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

            // Uses clean model name directly on the bar (e.g. "RX 7900 XTX:" or "RX 6400:")
            const prefix = (gpuBox.currentGpu && gpuBox.currentGpu.name)
                ? (gpuBox.currentGpu.name + ":")
                : "GPU:";

            return "<font color='" + ((shell && shell.theme) ? shell.theme.base0C : "#04f100") + "'>" + prefix + "</font> " +
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: gpuBox.detectedGpus.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && gpuBox.detectedGpus.length > 1) {
                gpuBox.cycleGpu();
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
                delegate: SlantedBox {
                    id: gpuBtnItem
                    width: gpuBtnText.implicitWidth + 24; height: 24
                    slantLeft: gpuBox.slantLeft
                    slantRight: gpuBox.slantRight
                    slantWidth: height * (gpuBox.slantWidth / gpuBox.height)
                    color: gpuBox.selectedGpuIndex === index ? ((shell && shell.theme) ? shell.theme.base05 : "yellow") : ((shell && shell.theme) ? shell.theme.base02 : "#222222")
                    borderColor: (shell && shell.theme) ? shell.theme.base05 : "yellow"
                    borderWidth: 1

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
                            if (shell && shell.settingsManager) {
                                shell.settingsManager.activeGpuCard = modelData.id;
                            }
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
            startY: 100
            listWidth: Math.min(360, gpuTooltip.effectiveCoreWidth - 64)
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
