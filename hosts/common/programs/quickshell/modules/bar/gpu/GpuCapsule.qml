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
    property bool pinTooltip: false
    property string searchQuery: ""

    // Dynamic GPU Model List: [ { id: "card0", render: "renderD128", name: "RX 7900" }, ... ]
    property var detectedGpus: []
    property int selectedGpuIndex: 0
    readonly property var currentGpu: (detectedGpus.length > selectedGpuIndex) ? detectedGpus[selectedGpuIndex] : null

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme && typeof shell.theme.base08 !== "undefined") ? shell.theme.base08 : "red"
    readonly property color themeBase09: (shell && shell.theme && typeof shell.theme.base09 !== "undefined") ? shell.theme.base09 : "orange"
    readonly property color themeBase0C: (shell && shell.theme && typeof shell.theme.base0C !== "undefined") ? shell.theme.base0C : "green"

    property int tooltipHeight: 420
    property int tooltipCollapsedWidth: 275
    property int tooltipExpandedWidth: 440
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 21

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
        return lines.filter(function(line) {
            return line.toLowerCase().indexOf(q) !== -1;
        });
    }

    width: 175
    Layout.preferredWidth: 175
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight
        slantWidth: gpuBox.slantWidth
    }

    // 1. HARDWARE GPU AUTO-DISCOVERY WITH CLEAN MODEL NUMBER PARSING
    Process {
        id: gpuDiscoveryProc
        running: true
        command: [
            "sh", "-c",
            "python3 -c '\n" +
            "import os, glob, json, re\n" +
            "\n" +
            "# Well-known AMD/Intel/Nvidia PCI Device IDs table for instant resolution\n" +
            "KNOWN = {\n" +
            "    \"1002:744c\": \"RX 7900\",\n" +
            "    \"1002:7448\": \"RX 7900\",\n" +
            "    \"1002:745e\": \"RX 7800\",\n" +
            "    \"1002:747e\": \"RX 7700\",\n" +
            "    \"1002:7480\": \"RX 7600\",\n" +
            "    \"1002:73bf\": \"RX 6900\",\n" +
            "    \"1002:73df\": \"RX 6700\",\n" +
            "    \"1002:73ff\": \"RX 6600\",\n" +
            "    \"1002:743f\": \"RX 6400\",\n" +
            "    \"1002:7422\": \"RX 6500\",\n" +
            "    \"10de:2684\": \"RTX 4090\",\n" +
            "    \"10de:2704\": \"RTX 4080\",\n" +
            "    \"8086:56a0\": \"Arc A770\",\n" +
            "}\n" +
            "\n" +
            "gpus = []\n" +
            "for card in sorted(glob.glob(\"/sys/class/drm/card[0-9]\")):\n" +
            "    card_name = os.path.basename(card)\n" +
            "    dev_link = os.path.realpath(f\"{card}/device\")\n" +
            "    \n" +
            "    # Match matching /dev/dri/renderD* node\n" +
            "    render = \"\"\n" +
            "    for r in glob.glob(\"/sys/class/drm/renderD*\"):\n" +
            "        if os.path.realpath(f\"{r}/device\") == dev_link:\n" +
            "            render = os.path.basename(r)\n" +
            "            break\n" +
            "            \n" +
            "    label = card_name.upper()\n" +
            "    try:\n" +
            "        with open(f\"{card}/device/vendor\") as f: ven = f.read().strip().replace(\"0x\", \"\").lower()\n" +
            "        with open(f\"{card}/device/device\") as f: dev = f.read().strip().replace(\"0x\", \"\").lower()\n" +
            "        dev_key = f\"{ven}:{dev}\"\n" +
            "        if dev_key in KNOWN:\n" +
            "            label = KNOWN[dev_key]\n" +
            "        else:\n" +
            "            # Search Linux pci.ids database for generic model numbers\n" +
            "            for pci_path in [\"/run/current-system/sw/share/hwdata/pci.ids\", \"/usr/share/hwdata/pci.ids\", \"/usr/share/misc/pci.ids\"]:\n" +
            "                if os.path.isfile(pci_path):\n" +
            "                    with open(pci_path, \"r\", errors=\"ignore\") as pf:\n" +
            "                        in_ven = False\n" +
            "                        for line in pf:\n" +
            "                            if line.startswith(ven):\n" +
            "                                in_ven = True; continue\n" +
            "                            elif in_ven and line and not line.startswith(\"\\t\"):\n" +
            "                                break\n" +
            "                            if in_ven and line.startswith(f\"\\t{dev}\"):\n" +
            "                                name = line.split(dev)[-1].strip()\n" +
            "                                m = re.search(r\"(RX\\s+\\d{4}|RTX\\s+\\d{4}|Arc\\s+[A-Z]\\d{3}|Radeon\\s+\\w+)\", name, re.I)\n" +
            "                                if m: label = m.group(1)\n" +
            "                                else: label = name.split()[0]\n" +
            "                                break\n" +
            "                    if label != card_name.upper(): break\n" +
            "    except:\n" +
            "        pass\n" +
            "        \n" +
            "    gpus.append({\"id\": card_name, \"render\": render, \"name\": label})\n" +
            "print(json.dumps(gpus))\n" +
            "'"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    if (parsed && parsed.length > 0) {
                        gpuBox.detectedGpus = parsed;
                    }
                } catch(e) {}
            }
        }
    }

    // 2. DYNAMIC HARDWARE METRICS READER
    Process {
        id: gpuStatsProc
        running: true
        command: [
            "sh", "-c",
            "card_id='" + (gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0") + "'; " +
            "card_dir=\"/sys/class/drm/$card_id/device\"; " +
            "[ ! -d \"$card_dir\" ] && echo '0:0:0:0' && exit; " +
            "usage=$(cat \"$card_dir/gpu_busy_percent\" 2>/dev/null || echo '0'); " +
            "temp=$(awk '{print int($1/1000)}' \"$card_dir/hwmon\"/hwmon*/temp1_input 2>/dev/null | head -n 1 || echo '0'); " +
            "power=$(awk '{print int($1/1000000)}' \"$card_dir/hwmon\"/hwmon*/power1_average 2>/dev/null | head -n 1 || echo '0'); " +
            "total=$(cat \"$card_dir/mem_info_vram_total\" 2>/dev/null || echo '0'); " +
            "used=$(cat \"$card_dir/mem_info_vram_used\" 2>/dev/null || echo '0'); " +
            "free_vram=$(awk -v t=\"$total\" -v u=\"$used\" 'BEGIN {printf \"%.0f\", (t-u)/1073741824}'); " +
            "echo \"$usage:$temp:$power:$free_vram\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 4) {
                    gpuBox.gpuUsageRaw = parts[0];
                    gpuBox.gpuTempRaw = parts[1];
                    gpuBox.gpuPowerRaw = parts[2];
                    gpuBox.gpuVramFreeRaw = parts[3];
                }
            }
        }
    }

    // 3. DYNAMIC PROCESS SCANNER
    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "sh", "-c",
            "target='" + (gpuBox.currentGpu ? gpuBox.currentGpu.render : "renderD128") + "'; " +
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
            "            p_engine = 0\n" +
            "            p_vram = 0\n" +
            "            has_target = False\n" +
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
            "                except Exception:\n" +
            "                    continue\n" +
            "            if has_target:\n" +
            "                data[pid] = (p_engine, p_vram)\n" +
            "        except Exception:\n" +
            "            continue\n" +
            "    return data\n" +
            "\n" +
            "s1 = sample()\n" +
            "time.sleep(0.12)\n" +
            "s2 = sample()\n" +
            "results = []\n" +
            "for pid, (e2, vram) in s2.items():\n" +
            "    e1 = s1.get(pid, (e2, 0))[0]\n" +
            "    diff = max(0, e2 - e1)\n" +
            "    pct = (diff / 120000000.0) * 100.0\n" +
            "    if pct < 0.1: continue\n" +
            "    try:\n" +
            "        with open(f\"/proc/{pid}/comm\", \"r\") as f: comm = f.read().strip()\n" +
            "    except: comm = \"unknown\"\n" +
            "    if comm in [\"sway\", \"Xwayland\"]:\n" +
            "        pct = max(0.1, pct - 0.5)\n" +
            "    mib = vram / (1024 * 1024)\n" +
            "    if mib >= 1024: vstr = f\"{mib/1024:3.1f}G\"\n" +
            "    elif mib > 0: vstr = f\"{int(mib):3d}M\"\n" +
            "    else: vstr = \"   - \"\n" +
            "    results.append((pid, comm, vstr, pct))\n" +
            "results.sort(key=lambda x: x[3], reverse=True)\n" +
            "out = []\n" +
            "for pid, comm, vstr, pct in results[:10]:\n" +
            "    out.append(f\"{pid}|{comm[:12]:<12} {vstr:>5} {pct:4.1f}%\")\n" +
            "if out: print(\"\\n\".join(out))\n" +
            "else: print(f\"No active GPU clients\")\n" +
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

    Timer {
        id: killRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            gpuBox.textAccumulatorBuffer = "";
            gpuProcFetcher.running = true;
        }
    }

    // Top Bar Pill Display
    Text {
        id: gpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const currentTemp = parseInt(gpuBox.gpuTempRaw) || 0;
            const currentFreeVram = parseInt(gpuBox.gpuVramFreeRaw) || 0;

            let tempColor = themeBase05.toString();
            if (currentTemp >= 80) tempColor = themeBase08.toString();
            else if (currentTemp >= 70) tempColor = themeBase09.toString();

            let vramColor = themeBase05.toString();
            if (currentFreeVram <= 4) vramColor = themeBase08.toString();
            else if (currentFreeVram <= 12) vramColor = themeBase09.toString();

            function formatStat(rawVal, targetLength, activeColor) {
                let padCount = targetLength - rawVal.length;
                let zerosStr = padCount > 0 ? "<font color='" + themeBase00.toString() + "'>" + "0".repeat(padCount) + "</font>" : "";
                return zerosStr + "<font color='" + activeColor + "'>" + rawVal + "</font>";
            }

            return "<font color='" + themeBase0C.toString() + "'>GPU:</font> " +
            formatStat(gpuBox.gpuUsageRaw, 2, themeBase05.toString()) + "<font color='" + themeBase05.toString() + "'>%</font> " +
                formatStat(gpuBox.gpuTempRaw, 2, tempColor) + "<font color='" + tempColor + "'>°C</font> " +
                    formatStat(gpuBox.gpuPowerRaw, 3, themeBase05.toString()) + "<font color='" + themeBase05.toString() + "'>W</font> " +
                        formatStat(gpuBox.gpuVramFreeRaw, 2, vramColor) + "<font color='" + vramColor + "'>GiB</font>";
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

        WlrLayershell.keyboardFocus: (gpuBox.pinTooltip || searchInput.activeFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
            HoverHandler {
                id: tooltipHoverTracker
            }
        }

        Text {
            text: "ACTIVE GPU CLIENTS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 20
            x: gpuTooltip.slantX(y) + 20
        }

        // Dynamic GPU Tabs
        Row {
            y: 13
            x: gpuTooltip.slantX(y) + 180
            spacing: 8

            Repeater {
                model: gpuBox.detectedGpus
                delegate: Item {
                    width: 82
                    height: 26

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: gpuBox.slantLeft
                        slantRight: gpuBox.slantRight
                        slantWidth: 10
                        color: gpuBox.selectedGpuIndex === index ? gpuBox.themeBase05 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        font.family: themeFontFamily
                        font.pixelSize: gpuBox.themeFontSize - 1
                        font.bold: true
                        color: gpuBox.selectedGpuIndex === index ? gpuBox.themeBase00 : gpuBox.themeBase05
                        elide: Text.ElideRight
                    }

                    TapHandler {
                        onTapped: {
                            gpuBox.selectedGpuIndex = index;
                            gpuBox.textAccumulatorBuffer = "";
                            gpuStatsProc.running = true;
                            gpuProcFetcher.running = true;
                        }
                    }
                }
            }
        }

        // Search Input
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

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search/Filter processes..."
                    color: gpuBox.themeBase05
                    opacity: 0.4
                    font.family: "monospace"
                    font.pixelSize: gpuBox.themeFontSize - 1
                    visible: searchInput.text === "" && !searchInput.activeFocus
                }
            }
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 345
            y: 84
            x: gpuTooltip.slantX(y) + 20
        }

        // Process List
        Repeater {
            model: gpuBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: gpuBox.filteredProcessLinesArray[index]
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
                    anchors.topMargin: -2
                    anchors.bottomMargin: -2
                    anchors.leftMargin: -4
                    anchors.rightMargin: -2
                    slantLeft: gpuBox.slantLeft
                    slantRight: gpuBox.slantRight
                    slantWidth: 12
                    visible: rowHoverTracker.hovered
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: killBtn.left
                    anchors.rightMargin: 6
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
                        slantLeft: gpuBox.slantLeft
                        slantRight: gpuBox.slantRight
                        slantWidth: 10
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: killBtnHover.hovered ? gpuBox.themeBase08 : gpuBox.themeBase08
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: killBtnHover }

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
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
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
