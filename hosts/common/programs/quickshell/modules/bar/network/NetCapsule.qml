import "../../common/Utils.js" as Utils
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: netBox

    property var barWindow: null
    property string moduleName: "net"
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: netBox.themeSlantWidth

    readonly property int themePadding: shell?.theme?.globalPadding ?? 12
    readonly property int themeFontSize: shell?.theme?.globalFontSize ?? 14
    readonly property string themeFontFamily: shell?.theme?.fontFamily ?? "monospace"
    readonly property int themeSlantWidth: shell?.theme?.slantWidth ?? 12
    readonly property var themeBase00: shell?.theme?.base00 ?? "black"
    readonly property var themeBase02: shell?.theme?.base02 ?? "gray"
    readonly property var themeBase05: shell?.theme?.base05 ?? "yellow"
    readonly property var themeBase08: shell?.theme?.base08 ?? "#fb4934"
    readonly property var themeBase0C: shell?.theme?.base0C ?? "#04f100"

    property string activeInterface: ""
    property string activeHwType: "Ethernet"
    property string activeIp: ""
    property string activeSpeed: ""

    property string downSpeedStr: "0B/s"
    property string upSpeedStr: "0B/s"
    property string pingStr: "--"

    property int tooltipHeight: 380
    property int tooltipCollapsedWidth: 260
    property int tooltipExpandedWidth: 500
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string topProcessesText: "Scanning network clients..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    implicitWidth: netText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: netBox.slantLeft
        slantRight: netBox.slantRight
        slantWidth: netBox.slantWidth
    }

    Process {
        id: netStatsProc
        running: true
        command: [
            "sh", "-c",
            'target=$(ip -4 route show default 2>/dev/null | awk \'/default/ {print $5; exit}\'); ' +
            '[ -z "$target" ] && target=$(awk \'$2 == "00000000" {print $1; exit}\' /proc/net/route 2>/dev/null); ' +
            'if [ -z "$target" ] || [ ! -d "/sys/class/net/$target/device" ]; then ' +
            '  for dev in /sys/class/net/*/device; do ' +
            '    iface=$(basename $(dirname "$dev")); state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null); ' +
            '    if [ "$state" = "up" ]; then target="$iface"; break; fi; ' +
            '  done; ' +
            'fi; ' +
            '[ -z "$target" ] && target=$(ls -1 /sys/class/net/ 2>/dev/null | grep -v "^lo$" | head -n 1); ' +
            '[ -z "$target" ] && echo "0:0:unknown:unknown:none:none" && exit; ' +
            'rx=$(cat "/sys/class/net/$target/statistics/rx_bytes" 2>/dev/null || echo 0); ' +
            'tx=$(cat "/sys/class/net/$target/statistics/tx_bytes" 2>/dev/null || echo 0); ' +
            'ip=$(ip -4 addr show "$target" 2>/dev/null | awk \'/inet / {print $2; exit}\' | cut -d/ -f1); ' +
            'speed=$(cat "/sys/class/net/$target/speed" 2>/dev/null || echo ""); ' +
            'is_wifi=$([ -d "/sys/class/net/$target/wireless" ] || [ -d "/sys/class/net/$target/phy80211" ] && echo "Wi-Fi" || echo "Ethernet"); ' +
            'printf "%s:%s:%s:%s:%s:%s\\n" "$rx" "$tx" "$target" "$is_wifi" "${ip:-none}" "${speed:-none}"'
        ]

        property real lastDown: 0
        property real lastUp: 0
        property bool isFirstRun: true

        function formatSpeed(bytesDiff) {
            return Utils.formatBytes(bytesDiff, 1).replace(" ", "") + "/s";
        }

        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length >= 6) {
                    var currentDown = parseFloat(parts[0]);
                    var currentUp = parseFloat(parts[1]);

                    netBox.activeInterface = parts[2].trim();
                    netBox.activeHwType = parts[3].trim();
                    netBox.activeIp = parts[4].trim() === "none" ? "" : parts[4].trim();
                    netBox.activeSpeed = (parts[5].trim() === "none" || parts[5].trim() === "") ? "" : (parts[5].trim() + " Mbps");

                    if (!netStatsProc.isFirstRun) {
                        var diffDown = Math.max(0, (currentDown - netStatsProc.lastDown) / 2.0);
                        var diffUp = Math.max(0, (currentUp - netStatsProc.lastUp) / 2.0);
                        netBox.downSpeedStr = netStatsProc.formatSpeed(diffDown);
                        netBox.upSpeedStr = netStatsProc.formatSpeed(diffUp);
                    }

                    netStatsProc.lastDown = currentDown;
                    netStatsProc.lastUp = currentUp;
                    netStatsProc.isFirstRun = false;
                }
            }
        }
    }

    Process {
        id: pingProc
        running: false
        command: [
            "sh", "-c",
            'gw=$(ip route show default 2>/dev/null | awk \'/default/ {print $3; exit}\'); ' +
            'host="${gw:-1.1.1.1}"; ' +
            'ping -c 1 -W 1 "$host" 2>/dev/null'
        ]
        stdout: SplitParser {
            onRead: data => {
                var match = data.match(/time=([0-9.]+)\s*ms/);
                if (match && match.length >= 2) {
                    var ms = parseFloat(match[1]);
                    netBox.pingStr = (ms < 1.0) ? "<1ms" : (Math.round(ms) + "ms");
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) netBox.pingStr = "OFFLINE";
        }
    }

    // Multi-Distro Network Client Monitor (NixOS wrappers, Arch, Mint, Debian, Fedora)
    Process {
        id: topNetProcFetcher
        running: false
        command: [
            "python3", "-c",
            "import sys, subprocess, os, re\n" +
            "iface = sys.argv[1] if len(sys.argv) > 1 else ''\n" +
            "bin_paths = ['/run/wrappers/bin/nethogs', '/usr/bin/nethogs', '/usr/sbin/nethogs', '/sbin/nethogs']\n" +
            "nh_bin = None\n" +
            "for p in bin_paths:\n" +
            "    if os.path.exists(p):\n" +
            "        nh_bin = p; break\n" +
            "if not nh_bin:\n" +
            "    import shutil\n" +
            "    nh_bin = shutil.which('nethogs')\n" +
            "results = []\n" +
            "if nh_bin:\n" +
            "    try:\n" +
            "        cmd = [nh_bin, '-t', '-c', '2']\n" +
            "        if iface: cmd.append(iface)\n" +
            "        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=3.0)\n" +
            "        cycle = 0\n" +
            "        speeds = {}\n" +
            "        for line in proc.stdout.splitlines():\n" +
            "            line = line.strip()\n" +
            "            if not line: continue\n" +
            "            if 'Refreshing:' in line:\n" +
            "                cycle += 1\n" +
            "                continue\n" +
            "            if cycle >= 2:\n" +
            "                parts = line.split()\n" +
            "                if len(parts) >= 3:\n" +
            "                    try:\n" +
            "                        sent = float(parts[1])\n" +
            "                        recv = float(parts[2])\n" +
            "                    except ValueError: continue\n" +
            "                    total = sent + recv\n" +
            "                    prog_full = parts[0]\n" +
            "                    subparts = prog_full.split('/')\n" +
            "                    if len(subparts) >= 3 and subparts[-1].isdigit() and subparts[-2].isdigit():\n" +
            "                        prog_name = subparts[-3]\n" +
            "                    else:\n" +
            "                        prog_name = subparts[-1]\n" +
            "                    if prog_name and 'unknown' not in prog_name:\n" +
            "                        speeds[prog_name] = speeds.get(prog_name, 0.0) + total\n" +
            "        for p, tot in sorted(speeds.items(), key=lambda x: x[1], reverse=True)[:8]:\n" +
            "            s_str = f'{tot:.1f} KB/s' if tot < 1024.0 else f'{tot/1024.0:.1f} MB/s'\n" +
            "            results.append(f'{p[:14]:<14} {s_str:>10}')\n" +
            "    except Exception: pass\n" +
            "if not results:\n" +
            "    try:\n" +
            "        out = subprocess.check_output(['ss', '-tupn'], stderr=subprocess.DEVNULL, text=True)\n" +
            "        counts = {}\n" +
            "        for line in out.splitlines()[1:]:\n" +
            "            m = re.search(r'users:\\(\\(\"([^\"]+)\"', line)\n" +
            "            if m:\n" +
            "                p = m.group(1)\n" +
            "                counts[p] = counts.get(p, 0) + 1\n" +
            "        for p, cnt in sorted(counts.items(), key=lambda x: x[1], reverse=True)[:8]:\n" +
            "            results.append(f'{p[:14]:<14} ({cnt} conns)')\n" +
            "    except Exception: pass\n" +
            "print('\\n'.join(results) if results else 'No active client traffic')",
            netBox.activeInterface
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") netBox.textAccumulatorBuffer += data + "\n";
            }
        }
        onExited: (exitCode) => {
            if (netBox.textAccumulatorBuffer.trim() !== "") {
                netBox.topProcessesText = netBox.textAccumulatorBuffer.trim();
            } else {
                netBox.topProcessesText = "No active client traffic";
            }
        }
    }

    Text {
        id: netText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2; anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true

        text: {
            const greenColor = themeBase0C.toString();
            const yellowColor = themeBase05.toString();
            const redColor = themeBase08.toString();
            const pingColor = netBox.pingStr === "OFFLINE" ? redColor : yellowColor;

            return "<font color='" + greenColor + "'>NET:</font> " +
                "<font color='" + yellowColor + "'>▼</font><font color='" + yellowColor + "'>" + netBox.downSpeedStr + "</font> " +
                "<font color='" + yellowColor + "'>▲</font><font color='" + yellowColor + "'>" + netBox.upSpeedStr + "</font> " +
                " <font color='" + pingColor + "'>" + netBox.pingStr + "</font>";
        }
    }

    HoverHandler {
        id: netHoverTracker
        onHoveredChanged: {
            if (hovered && !topNetProcFetcher.running) {
                netBox.textAccumulatorBuffer = "";
                topNetProcFetcher.running = true;
            }
        }
    }

    SlantedTooltip {
        id: netTooltip
        moduleItem: netBox
        barWindow: netBox.barWindow
        tooltipActive: netHoverTracker.hovered
        pin: false

        tooltipHeight: netBox.tooltipHeight
        collapsedCoreWidth: netBox.tooltipCollapsedWidth
        expandedCoreWidth: netBox.tooltipExpandedWidth
        topOffset: netBox.tooltipTopOffset
        rightOffset: netBox.tooltipRightOffset
        slantLeft: netBox.slantLeft
        slantRight: netBox.slantRight

        Text {
            y: 20
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            text: "DEFAULT NETWORK DEVICE:"
            font.family: themeFontFamily
            font.pixelSize: Math.max(12, themeFontSize - 1)
            font.bold: true
            color: themeBase05
            elide: Text.ElideRight
        }

        Row {
            y: 46
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            spacing: 8

            Text {
                text: "● " + netBox.activeHwType + " (" + (netBox.activeInterface || "none") + ")"
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                font.bold: true
                color: themeBase0C
            }

            Text {
                visible: netBox.activeSpeed !== ""
                text: "• " + netBox.activeSpeed
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: themeBase05
                opacity: 0.8
            }
        }

        Row {
            y: 70
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            spacing: 12

            Text {
                visible: netBox.activeIp !== ""
                text: "IP: " + netBox.activeIp
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: themeBase05
                opacity: 0.85
            }

            Text {
                text: "Ping: " + netBox.pingStr
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: netBox.pingStr === "OFFLINE" ? themeBase08 : themeBase05
                opacity: 0.85
            }
        }

        Text {
            y: 98
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            text: "ACTIVE NETWORK CLIENTS:"
            font.family: themeFontFamily
            font.pixelSize: Math.max(12, themeFontSize - 1)
            font.bold: true
            color: themeBase05
            elide: Text.ElideRight
        }

        Repeater {
            model: netBox.processLinesArray.length
            Text {
                y: 124 + (index * 24)
                x: netTooltip.slantX(y) + 24
                width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
                text: netBox.processLinesArray[index]
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: themeBase05
                elide: Text.ElideRight
            }
        }
    }

    Timer {
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000
        running: true; repeat: true; triggeredOnStart: true
        property int ticks: 0

        onTriggered: {
            netStatsProc.running = false;
            if (netHoverTracker.hovered || netBox.pinTooltip) netStatsProc.running = true;
            ticks++;
            if (ticks >= 15) {
                ticks = 0;
                pingProc.running = false;
                pingProc.running = true;
            }
            if (netHoverTracker.hovered && !topNetProcFetcher.running) {
                netBox.textAccumulatorBuffer = "";
                topNetProcFetcher.running = true;
            }
        }
    }
}
