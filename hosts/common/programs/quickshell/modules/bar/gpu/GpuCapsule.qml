// GpuCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

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

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "#f7f700"
    readonly property color themeBase08: (shell && shell.theme && typeof shell.theme.base08 !== "undefined") ? shell.theme.base08 : "#ff0000"
    readonly property color themeBase09: (shell && shell.theme && typeof shell.theme.base09 !== "undefined") ? shell.theme.base09 : "#fe8019"
    readonly property color themeBase0C: (shell && shell.theme && typeof shell.theme.base0C !== "undefined") ? shell.theme.base0C : "#04f100"

    property int tooltipHeight: 420
    property int tooltipCollapsedWidth: 275
    property int tooltipExpandedWidth: 520
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: gpuBox.themeSlantWidth

    property string gpuUsageRaw: "0"
    property string gpuTempRaw: "0"
    property string gpuPowerRaw: "0"
    property string gpuVramFreeRaw: "0"
    property string topGpuProcessesText: "Loading GPU processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topGpuProcessesText.split("\n").filter(line => line.trim() !== "")
    readonly property var filteredProcessLinesArray: {
        var lines = processLinesArray;
        if (searchQuery.trim() === "") return lines;
        var q = searchQuery.trim().toLowerCase();
        return lines.filter(function(line) { return line.toLowerCase().indexOf(q) !== -1; });
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

    // Dynamic Hardware Metrics Reader (Outputs FREE VRAM in GiB)
    Process {
        id: gpuStatsProc
        running: true
        command: [
            "sh", "-c",
            'card_id="' + (gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0") + '"; ' +
            'card_dir="/sys/class/drm/$card_id/device"; ' +
            '[ ! -d "$card_dir" ] && echo "0:0:0:0" && exit; ' +
            'usage=$(cat "$card_dir/gpu_busy_percent" 2>/dev/null | tr -dc "0-9"); ' +
            '[ -z "$usage" ] && usage="0"; ' +
            'temp=$(awk \'{print int($1/1000); exit}\' "$card_dir/hwmon"/hwmon*/temp*_input 2>/dev/null || echo "0"); ' +
            'power=$(awk \'{print int($1/1000000); exit}\' "$card_dir/hwmon"/hwmon*/power1_* 2>/dev/null || echo "0"); ' +
            'total=$(cat "$card_dir/mem_info_vram_total" 2>/dev/null || echo "0"); ' +
            'used=$(cat "$card_dir/mem_info_vram_used" 2>/dev/null || echo "0"); ' +
            'if [ "$total" = "0" ] || [ -z "$total" ]; then ' +
            '  total=$(cat "$card_dir/mem_info_gtt_total" 2>/dev/null || echo "0"); ' +
            '  used=$(cat "$card_dir/mem_info_gtt_used" 2>/dev/null || echo "0"); ' +
            'fi; ' +
            'free_vram=$(awk -v t="$total" -v u="$used" \'BEGIN {if(t>u) printf "%.0f", (t-u)/1073741824; else print "0"}\'); ' +
            'printf "%s:%s:%s:%s\\n" "$usage" "$temp" "$power" "$free_vram"'
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

    // Process Scanner for Active GPU Clients
    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "sh", "-c",
            "target='" + (gpuBox.currentGpu && gpuBox.currentGpu.render ? gpuBox.currentGpu.render : "renderD128") + "'; " +
            "python3 -c '\n" +
            "import os, time, sys\n" +
            "target = sys.argv[1]\n" +
            "def sample():\n" +
            "    data = {}\n" +
            "    for pid in os.listdir(\"/proc\"):\n" +
            "        if not pid.isdigit(): continue\n" +
            "        fd_dir = f\"/proc/{pid}/fd\"\n" +
            "        fdinfo_dir = f\"/proc/{pid}/fdinfo\"\n" +
            "        try:\n" +
            "            p_engine = 0; p_vram = 0; has_target = False\n" +
            "            for fd in os.listdir(fd_dir):\n" +
            "                try:\n" +
            "                    if target in os.readlink(f\"{fd_dir}/{fd}\"):\n" +
            "                        has_target = True\n" +
            "                        with open(f\"{fdinfo_dir}/{fd}\", \"r\") as f:\n" +
            "                            for line in f:\n" +
            "                                if line.startswith(\"drm-engine-gfx:\") or line.startswith(\"drm-engine-compute:\"):\n" +
            "                                    p_engine += int(line.split()[1])\n" +
            "                                elif line.startswith(\"drm-total-vram:\") or line.startswith(\"drm-resident-vram:\"):\n" +
            "                                    v = int(line.split()[1])\n" +
            "                                    if \"KiB\" in line: v *= 1024\n" +
            "                                    p_vram = max(p_vram, v)\n" +
            "                except Exception: continue\n" +
            "            if has_target: data[pid] = (p_engine, p_vram)\n" +
            "        except Exception: continue\n" +
            "    return data\n" +
            "s1 = sample(); time.sleep(0.12); s2 = sample()\n" +
            "results = []\n" +
            "for pid, (e2, vram) in s2.items():\n" +
            "    e1 = s1.get(pid, (e2, 0))[0]\n" +
            "    diff = max(0, e2 - e1)\n" +
            "    pct = (diff / 120000000.0) * 100.0\n" +
            "    if pct < 0.1: continue\n" +
            "    try:\n" +
            "        with open(f\"/proc/{pid}/comm\", \"r\") as f: comm = f.read().strip()\n" +
            "    except: comm = \"unknown\"\n" +
            "    mib = vram / (1024 * 1024)\n" +
            "    vstr = f\"{mib/1024:3.1f}G\" if mib >= 1024 else (f\"{int(mib):3d}M\" if mib > 0 else \"   - \")\n" +
            "    results.append((pid, comm, vstr, pct))\n" +
            "results.sort(key=lambda x: x[3], reverse=True)\n" +
            "out = [f\"{pid}|{comm[:12]:<12} {vstr:>5} {pct:4.1f}%\" for pid, comm, vstr, pct in results[:10]]\n" +
            "print(\"\\n\".join(out) if out else \"No active GPU clients\")\n" +
            "' \"$target\""
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") gpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            gpuBox.topGpuProcessesText = gpuBox.textAccumulatorBuffer.trim() !== "" ? gpuBox.textAccumulatorBuffer.trim() : "No active GPU clients";
        }
    }

    Process {
        id: killProc
        function killPid(pid) {
            if (!pid) return;
            command = ["kill", "-9", pid.toString()];
            running = true;
        }
    }

    Text {
        id: gpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 6
        anchors.rightMargin: bg.rightPadding + 6
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        color: themeBase05
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

            let tempColor = themeBase05.toString();
            if (currentTemp >= tDanger) tempColor = themeBase08.toString();
            else if (currentTemp >= tWarn) tempColor = themeBase09.toString();

            let vramColor = themeBase05.toString();
            if (currentFreeVram <= vDanger) vramColor = themeBase08.toString();
            else if (currentFreeVram <= vWarn) vramColor = themeBase09.toString();

            return "<font color='" + themeBase0C.toString() + "'>GPU:</font> " +
                "<font color='" + themeBase05.toString() + "'>" + usageVal + "%</font> " +
                "<font color='" + tempColor + "'>" + currentTemp + "°C</font> " +
                "<font color='" + themeBase05.toString() + "'>" + currentPower + "W</font> " +
                "<font color='" + vramColor + "'>" + currentFreeVram + "GiB</font>";
        }
    }

    HoverHandler {
        id: gpuHoverTracker
        onHoveredChanged: {
            if (hovered && !gpuTooltip.isHovered && !searchInput.activeFocus) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            gpuBox.pinTooltip = !gpuBox.pinTooltip;
            if (gpuBox.pinTooltip && !searchInput.activeFocus) {
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

        keyboardFocus: (gpuBox.pinTooltip || searchInput.activeFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        readonly property bool isHovered: tooltipHoverTracker.hovered

        tooltipHeight: gpuBox.tooltipHeight
        collapsedCoreWidth: gpuBox.tooltipCollapsedWidth
        expandedCoreWidth: gpuBox.tooltipExpandedWidth
        topOffset: gpuBox.tooltipTopOffset
        rightOffset: gpuBox.tooltipRightOffset
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight

        Item {
            anchors.fill: parent
            HoverHandler { id: tooltipHoverTracker }
        }

        RowLayout {
            y: 16
            x: gpuTooltip.slantX(y) + 20
            spacing: 8

            Text {
                text: "GPU:"
                font.family: themeFontFamily
                font.pixelSize: themeFontSize - 1
                font.bold: true
                color: themeBase05
            }

            Repeater {
                model: gpuBox.detectedGpus
                delegate: Rectangle {
                    width: gpuBtnText.implicitWidth + 16
                    height: 24
                    radius: 4
                    color: gpuBox.selectedGpuIndex === index ? themeBase05 : themeBase02
                    border.width: 1
                    border.color: themeBase05

                    Text {
                        id: gpuBtnText
                        anchors.centerIn: parent
                        text: (modelData.name || modelData.id)
                        font.family: themeFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: gpuBox.selectedGpuIndex === index ? themeBase00 : themeBase05
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            gpuBox.selectedGpuIndex = index;
                            gpuBox.textAccumulatorBuffer = "";
                            gpuStatsProc.running = false;
                            gpuStatsProc.running = true;
                            gpuProcFetcher.running = false;
                            gpuProcFetcher.running = true;
                        }
                    }
                }
            }
        }

        Item {
            id: searchContainer
            y: 48
            x: gpuTooltip.slantX(y) + 20
            width: 345
            height: 26

            SlantedBox {
                anchors.fill: parent
                slantLeft: gpuBox.slantLeft
                slantRight: gpuBox.slantRight
                slantWidth: 12
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: gpuBox.themeBase05
                font.family: "monospace"
                font.pixelSize: gpuBox.themeFontSize - 1
                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnPress: true
                onTextChanged: gpuBox.searchQuery = text

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (searchInput.text !== "") {
                            searchInput.text = "";
                        } else {
                            gpuBox.pinTooltip = false;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search/Filter processes... [Esc to close]"
                    color: gpuBox.themeBase05
                    opacity: 0.4
                    font.family: "monospace"
                    font.pixelSize: gpuBox.themeFontSize - 1
                    visible: searchInput.text === "" && !searchInput.activeFocus
                }
            }
        }

        Repeater {
            model: gpuBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: (index < gpuBox.filteredProcessLinesArray.length) ? gpuBox.filteredProcessLinesArray[index] : ""
                readonly property var parts: rawLine.split("|")
                readonly property string pid: parts.length > 1 ? parts[0] : ""
                readonly property string displayText: parts.length > 1 ? parts[1] : rawLine

                y: 100 + (index * 28)
                x: gpuTooltip.slantX(y) + 20
                width: 345
                height: 22

                HoverHandler { id: rowHoverTracker }

                SlantedBox {
                    anchors.fill: parent
                    anchors.topMargin: -2; anchors.bottomMargin: -2
                    anchors.leftMargin: -4; anchors.rightMargin: -2
                    slantLeft: gpuBox.slantLeft; slantRight: gpuBox.slantRight
                    slantWidth: 12
                    visible: rowHoverTracker.hovered
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.right: killBtn.left; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: processRow.displayText
                    font.family: "monospace"
                    font.pixelSize: gpuBox.themeFontSize - 1
                    color: gpuBox.themeBase05
                    elide: Text.ElideNone
                }

                Item {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 18
                    visible: processRow.pid !== ""

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: gpuBox.slantLeft; slantRight: gpuBox.slantRight
                        slantWidth: 10
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: gpuBox.themeBase08
                        font.pixelSize: 11
                        font.bold: true
                    }

                    TapHandler {
                        onTapped: {
                            if (processRow.pid !== "") {
                                killProc.killPid(processRow.pid);
                                killRefreshTimer.start();
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: killRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            gpuBox.textAccumulatorBuffer = "";
            gpuProcFetcher.running = true;
        }
    }

    Timer {
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            gpuStatsProc.running = false;
            gpuStatsProc.running = true;
            if ((gpuHoverTracker.hovered || gpuBox.pinTooltip) && !gpuTooltip.isHovered && !searchInput.activeFocus) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }
}
