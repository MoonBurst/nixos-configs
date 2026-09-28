import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: manager

    property string nixThemeFile: Quickshell.env("HOME") + "/nix/hosts/common/theme.nix"

    property bool useStylix: false
    property bool animationsEnabled: true

    property string slantStyleMode: "symmetric"
    property int capsuleSpacing: 2
    property int slantRevision: 0
    property int gpuThresholdRevision: 0

    property int globalFontSize: 14
    property int slantWidth: 12
    property int globalBorderWidth: 3
    property int globalPadding: 12

    // TOP BAR & HARDWARE TIMINGS
    property int barHeight: 42
    property int hardwarePollInterval: 2000

    // LAUNCHER CUSTOMIZATION
    property int launcherWidth: 840
    property int launcherHeight: 700
    property int appItemHeight: 80
    property int appIconSize: 32

    // STORAGE & AUDIO
    property string notesFilePath: Quickshell.env("HOME") + "/Documents/notes.txt"
    property int notifVolume: 80

    // OVERLAYS & TOOLS CONFIGURATION
    property int notifBaselineY: 350
    property int notifStackOverlap: 25
    property string notifScreenName: ""
    property real magnifierDefaultZoom: 8.0
    property int magnifierLensSize: 300
    property string screenshotSaveDir: Quickshell.env("HOME") + "/Screenshots"
    property string defaultWatermarkTag: ""
    property int quickshotHistoryLimit: 50
    property string geminiModelName: "gemini-flash-latest"
    property int clipboardMaxItems: 200
    property string defaultLauncherMode: "apps"
    property string emailSignature: "\n\n--\nSeekers of light..\nBelieve not in justice...\nBelieve not in truth...\nFor they are empty and inconsistent, as are all things..."

    // THEME DEFAULTS
    property string customBase00: "#0f0f0f"
    property string customBase03: "#003399"
    property string customBase05: "#f7f700"
    property string customBase08: "#ff0000"
    property string customBase09: "#fe8019"
    property string customBase0C: "#04f100"
    property string customBase0D: "#003399"

    // GPU DISCOVERY
    property var discoveredGpus: []
    property string activeGpuCard: "card0"

    property int gpu0TempWarn: 70
    property int gpu0TempDanger: 80
    property int gpu0VramWarn: 4
    property int gpu0VramDanger: 2

    property int gpu1TempWarn: 65
    property int gpu1TempDanger: 75
    property int gpu1VramWarn: 1
    property int gpu1VramDanger: 0

    function getGpuTempWarn(cardId) { return (cardId === "card1" || cardId === 1) ? gpu1TempWarn : gpu0TempWarn; }
    function getGpuTempDanger(cardId) { return (cardId === "card1" || cardId === 1) ? gpu1TempDanger : gpu0TempDanger; }
    function getGpuVramWarn(cardId) { return (cardId === "card1" || cardId === 1) ? gpu1VramWarn : gpu0VramWarn; }
    function getGpuVramDanger(cardId) { return (cardId === "card1" || cardId === 1) ? gpu1VramDanger : gpu0VramDanger; }

    function setGpuThreshold(cardId, key, val) {
        var num = Math.round(val);
        var isCard1 = (cardId === "card1" || cardId === 1);
        if (isCard1) {
            if (key === "tempWarn") gpu1TempWarn = num;
            else if (key === "tempDanger") gpu1TempDanger = num;
            else if (key === "vramWarn") gpu1VramWarn = num;
            else if (key === "vramDanger") gpu1VramDanger = num;
        } else {
            if (key === "tempWarn") gpu0TempWarn = num;
            else if (key === "tempDanger") gpu0TempDanger = num;
            else if (key === "vramWarn") gpu0VramWarn = num;
            else if (key === "vramDanger") gpu0VramDanger = num;
        }
        gpuThresholdRevision++;
        saveToDisk();
    }

    function syncStylixDefaults() {
        if (shell && shell.theme) {
            if (shell.theme.globalFontSize !== undefined) globalFontSize = shell.theme.globalFontSize;
            if (shell.theme.slantWidth !== undefined) slantWidth = shell.theme.slantWidth;
            if (shell.theme.globalBorderWidth !== undefined) globalBorderWidth = shell.theme.globalBorderWidth;
            if (shell.theme.globalPadding !== undefined) globalPadding = shell.theme.globalPadding;
            if (shell.theme.base00 !== undefined) customBase00 = shell.theme.base00.toString();
            if (shell.theme.base03 !== undefined) customBase03 = shell.theme.base03.toString();
            if (shell.theme.base05 !== undefined) customBase05 = shell.theme.base05.toString();
            if (shell.theme.base08 !== undefined) customBase08 = shell.theme.base08.toString();
            if (shell.theme.base09 !== undefined) customBase09 = shell.theme.base09.toString();
            if (shell.theme.base0C !== undefined) customBase0C = shell.theme.base0C.toString();
            if (shell.theme.base0D !== undefined) customBase0D = shell.theme.base0D.toString();
        }
        saveToDisk();
    }

    Process {
        id: gpuDiscProc
        running: true
        command: [
            "python3", "-c",
            "import os, glob, json\n" +
            "KNOWN = {'1002:743f':'RX 6400','1002:743c':'RX 6500 XT','1002:73ff':'RX 6600 XT','1002:73df':'RX 6700 XT','1002:73bf':'RX 6800 / 6900 XT','1002:744c':'RX 7900 XTX','1002:7448':'RX 7900 XT','1002:745e':'RX 7800 XT','1002:747e':'RX 7700 XT','1002:7480':'RX 7600','1002:164e':'Radeon 680M/780M','10de:2684':'RTX 4090','10de:2704':'RTX 4080','10de:2782':'RTX 4070 Ti','10de:2786':'RTX 4070','10de:2860':'RTX 4060 Ti','10de:2882':'RTX 4060','10de:2204':'RTX 3090','10de:2206':'RTX 3080','10de:2484':'RTX 3070','10de:2503':'RTX 3060','8086:56a0':'Intel Arc A770','8086:56a1':'Intel Arc A750'}\n" +
            "gpus = []\n" +
            "for card in sorted(glob.glob('/sys/class/drm/card[0-9]')):\n" +
            "    cname = os.path.basename(card)\n" +
            "    dlink = os.path.realpath(card + '/device')\n" +
            "    render = next((os.path.basename(r) for r in glob.glob('/sys/class/drm/renderD*') if os.path.realpath(r + '/device') == dlink), '')\n" +
            "    label, hw_id = cname.upper(), ''\n" +
            "    try:\n" +
            "        with open(card + '/device/vendor') as f: ven = f.read().strip().replace('0x', '').lower()\n" +
            "        with open(card + '/device/device') as f: dev = f.read().strip().replace('0x', '').lower()\n" +
            "        hw_id = ven + ':' + dev\n" +
            "        if hw_id in KNOWN: label = KNOWN[hw_id]\n" +
            "        elif ven == '1002': label = 'Radeon Graphics'\n" +
            "        elif ven == '8086': label = 'Intel Graphics'\n" +
            "    except: pass\n" +
            "    if not hw_id: hw_id = cname\n" +
            "    gpus.append({'id': cname, 'hw_id': hw_id, 'render': render, 'name': label})\n" +
            "print(json.dumps(gpus))\n"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    if (parsed && parsed.length > 0) manager.discoveredGpus = parsed;
                } catch(e) {}
            }
        }
    }

    property int masterVolume: 80
    property int micVolume: 100
    property bool micMuted: false
    property bool notificationsEnabled: true
    property int notifHoldDurationSec: 5
    property bool enableTts: true

    property var barLeftModules: ["calendar", "music", "alarm", "weather", "unified", "notify"]
    property var barCenterModules: ["audio", "clock", "mic"]
    property var barRightModules: ["tray", "ram", "gpu", "cpu", "net", "battery"]

    function getLeftList() { return barLeftModules.length > 0 ? barLeftModules : ["calendar", "music", "alarm", "weather", "unified", "notify"]; }
    function getCenterList() { return barCenterModules.length > 0 ? barCenterModules : ["audio", "clock", "mic"]; }
    function getRightList() { return barRightModules.length > 0 ? barRightModules : ["tray", "ram", "gpu", "cpu", "net", "battery"]; }

    // PER-CAPSULE TOOLTIP DIMENSIONS
    property string previewCapsule: ""
    property var capsuleDimensions: ({})
    property int dimensionsRevision: 0

    function getCapsuleWidth(idStr) {
        if (capsuleDimensions && capsuleDimensions[idStr] && capsuleDimensions[idStr].width > 0) {
            return capsuleDimensions[idStr].width;
        }
        return 0;
    }

    function getCapsuleHeight(idStr) {
        if (capsuleDimensions && capsuleDimensions[idStr] && capsuleDimensions[idStr].height > 0) {
            return capsuleDimensions[idStr].height;
        }
        return 0;
    }

    function setCapsuleWidth(idStr, w) {
        var copy = Object.assign({}, capsuleDimensions);
        if (!copy[idStr]) copy[idStr] = {};
        copy[idStr].width = Math.round(w);
        capsuleDimensions = copy;
        dimensionsRevision++;
        saveToDisk();
    }

    function setCapsuleHeight(idStr, h) {
        var copy = Object.assign({}, capsuleDimensions);
        if (!copy[idStr]) copy[idStr] = {};
        copy[idStr].height = Math.round(h);
        capsuleDimensions = copy;
        dimensionsRevision++;
        saveToDisk();
    }

    function resetCapsuleSize(idStr) {
        var copy = Object.assign({}, capsuleDimensions);
        delete copy[idStr];
        capsuleDimensions = copy;
        dimensionsRevision++;
        saveToDisk();
    }

    property var capsuleSlants: ({})

    function getModuleSlant(idStr, section) {
        if (capsuleSlants && capsuleSlants[idStr] && capsuleSlants[idStr] !== "auto") return capsuleSlants[idStr];
        if (slantStyleMode === "all-left") return "left";
        if (slantStyleMode === "all-right") return "right";
        if (section === "left") return "left";
        if (section === "right") return "right";
        return idStr === "clock" ? "center" : (idStr === "mic" ? "right" : "left");
    }

    function setModuleSlant(idStr, slantType) {
        var copy = Object.assign({}, capsuleSlants);
        copy[idStr] = slantType;
        capsuleSlants = copy;
        slantRevision++;
        saveToDisk();
    }

    property var visibleCapsules: ({
        "calendar": true, "music": true, "alarm": true, "weather": true,
        "unified": true, "notify": true, "clock": true, "audio": true,
        "mic": true, "net": true, "cpu": true, "gpu": true, "ram": true, "tray": true, "battery": true
    })

    function isCapsuleVisible(idStr) { return visibleCapsules[idStr] !== undefined ? visibleCapsules[idStr] : true; }
    function toggleCapsuleVisibility(idStr) {
        var copy = Object.assign({}, visibleCapsules);
        copy[idStr] = !copy[idStr];
        visibleCapsules = copy;
        saveToDisk();
    }

    function moveWithinSection(section, fromIdx, toIdx) {
        var list = (section === "left" ? getLeftList() : (section === "center" ? getCenterList() : getRightList())).slice();
        if (toIdx < 0 || toIdx >= list.length) return;
        var item = list.splice(fromIdx, 1)[0];
        list.splice(toIdx, 0, item);
        if (section === "left") barLeftModules = list;
        else if (section === "center") barCenterModules = list;
        else barRightModules = list;
        saveToDisk();
    }

    function moveModule(idStr, targetSection, newIndex) {
        var l = getLeftList().slice().filter(x => x !== idStr);
        var c = getCenterList().slice().filter(x => x !== idStr);
        var r = getRightList().slice().filter(x => x !== idStr);
        if (targetSection === "left") l.splice(Math.max(0, Math.min(newIndex, l.length)), 0, idStr);
        else if (targetSection === "center") c.splice(Math.max(0, Math.min(newIndex, c.length)), 0, idStr);
        else if (targetSection === "right") r.splice(Math.max(0, Math.min(newIndex, r.length)), 0, idStr);
        barLeftModules = l;
        barCenterModules = c;
        barRightModules = r;
        saveToDisk();
    }

    property bool isLoaded: false

    Timer {
        id: saveDebounceTimer
        interval: 100; repeat: false; onTriggered: manager.saveToDisk()
    }

    function queueSave() { if (manager.isLoaded) saveDebounceTimer.restart(); }

    onAnimationsEnabledChanged: queueSave()
    onSlantStyleModeChanged: { slantRevision++; queueSave(); }
    onCapsuleSpacingChanged: queueSave()
    onGlobalFontSizeChanged: queueSave()
    onSlantWidthChanged: queueSave()
    onGlobalBorderWidthChanged: queueSave()
    onGlobalPaddingChanged: queueSave()

    onBarHeightChanged: queueSave()
    onHardwarePollIntervalChanged: queueSave()
    onLauncherWidthChanged: queueSave()
    onLauncherHeightChanged: queueSave()
    onAppItemHeightChanged: queueSave()
    onAppIconSizeChanged: queueSave()
    onNotesFilePathChanged: queueSave()
    onNotifVolumeChanged: queueSave()

    onNotifBaselineYChanged: queueSave()
    onNotifStackOverlapChanged: queueSave()
    onNotifScreenNameChanged: queueSave()
    onMagnifierDefaultZoomChanged: queueSave()
    onMagnifierLensSizeChanged: queueSave()
    onScreenshotSaveDirChanged: queueSave()
    onDefaultWatermarkTagChanged: queueSave()
    onQuickshotHistoryLimitChanged: queueSave()
    onGeminiModelNameChanged: queueSave()
    onClipboardMaxItemsChanged: queueSave()
    onDefaultLauncherModeChanged: queueSave()
    onEmailSignatureChanged: queueSave()

    onGpu0TempWarnChanged: queueSave()
    onGpu0TempDangerChanged: queueSave()
    onGpu0VramWarnChanged: queueSave()
    onGpu0VramDangerChanged: queueSave()
    onGpu1TempWarnChanged: queueSave()
    onGpu1TempDangerChanged: queueSave()
    onGpu1VramWarnChanged: queueSave()
    onGpu1VramDangerChanged: queueSave()

    onCustomBase00Changed: queueSave()
    onCustomBase03Changed: queueSave()
    onCustomBase05Changed: queueSave()
    onCustomBase08Changed: queueSave()
    onCustomBase09Changed: queueSave()
    onCustomBase0CChanged: queueSave()
    onCustomBase0DChanged: queueSave()

    onMasterVolumeChanged: {
        queueSave();
        syncMasterVolumeProcess.running = false;
        syncMasterVolumeProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (masterVolume / 100.0).toFixed(2)];
        syncMasterVolumeProcess.running = true;
    }
    onMicVolumeChanged: {
        queueSave();
        syncMicVolumeProcess.running = false;
        syncMicVolumeProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (micVolume / 100.0).toFixed(2)];
        syncMicVolumeProcess.running = true;
    }
    onMicMutedChanged: {
        queueSave();
        syncMicMuteProcess.running = false;
        syncMicMuteProcess.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", micMuted ? "1" : "0"];
        syncMicMuteProcess.running = true;
    }

    Process { id: syncMasterVolumeProcess; running: false }
    Process { id: syncMicVolumeProcess; running: false }
    Process { id: syncMicMuteProcess; running: false }
    Process { id: writerProc; running: false }

    function saveToDisk() {
        var data = {
            "useStylix": manager.useStylix,
            "animationsEnabled": manager.animationsEnabled,
            "slantStyleMode": manager.slantStyleMode,
            "capsuleSpacing": manager.capsuleSpacing,
            "globalFontSize": manager.globalFontSize,
            "slantWidth": manager.slantWidth,
            "globalBorderWidth": manager.globalBorderWidth,
            "globalPadding": manager.globalPadding,
            "barHeight": manager.barHeight,
            "hardwarePollInterval": manager.hardwarePollInterval,
            "launcherWidth": manager.launcherWidth,
            "launcherHeight": manager.launcherHeight,
            "appItemHeight": manager.appItemHeight,
            "appIconSize": manager.appIconSize,
            "notesFilePath": manager.notesFilePath,
            "notifVolume": manager.notifVolume,
            "notifBaselineY": manager.notifBaselineY,
            "notifStackOverlap": manager.notifStackOverlap,
            "notifScreenName": manager.notifScreenName,
            "magnifierDefaultZoom": manager.magnifierDefaultZoom,
            "magnifierLensSize": manager.magnifierLensSize,
            "screenshotSaveDir": manager.screenshotSaveDir,
            "defaultWatermarkTag": manager.defaultWatermarkTag,
            "quickshotHistoryLimit": manager.quickshotHistoryLimit,
            "geminiModelName": manager.geminiModelName,
            "clipboardMaxItems": manager.clipboardMaxItems,
            "defaultLauncherMode": manager.defaultLauncherMode,
            "emailSignature": manager.emailSignature,
            "activeGpuCard": manager.activeGpuCard,
            "gpu0": { "tempWarn": manager.gpu0TempWarn, "tempDanger": manager.gpu0TempDanger, "vramWarn": manager.gpu0VramWarn, "vramDanger": manager.gpu0VramDanger },
            "gpu1": { "tempWarn": manager.gpu1TempWarn, "tempDanger": manager.gpu1TempDanger, "vramWarn": manager.gpu1VramWarn, "vramDanger": manager.gpu1VramDanger },
            "customColors": {
                "base00": manager.customBase00, "base03": manager.customBase03, "base05": manager.customBase05,
                "base08": manager.customBase08, "base09": manager.customBase09, "base0C": manager.customBase0C, "base0D": manager.customBase0D
            },
            "notificationsEnabled": manager.notificationsEnabled,
            "notifHoldDurationSec": manager.notifHoldDurationSec,
            "enableTts": manager.enableTts,
            "masterVolume": manager.masterVolume,
            "micVolume": manager.micVolume,
            "micMuted": manager.micMuted,
            "barLeft": manager.getLeftList(),
            "barCenter": manager.getCenterList(),
            "barRight": manager.getRightList(),
            "capsuleSlants": manager.capsuleSlants,
            "capsuleDimensions": manager.capsuleDimensions,
            "visibleCapsules": manager.visibleCapsules
        };

        var jsonStr = JSON.stringify(data);

        writerProc.running = false;
        writerProc.command = [
            "python3", "-c",
            "import sys, os\n" +
            "f_path = os.path.expanduser('~/.config/quickshell/settings.json')\n" +
            "os.makedirs(os.path.dirname(f_path), exist_ok=True)\n" +
            "tmp_path = f_path + '.tmp'\n" +
            "with open(tmp_path, 'w') as f: f.write(sys.argv[1])\n" +
            "os.replace(tmp_path, f_path)\n",
            jsonStr
        ];
        writerProc.running = true;
    }

    Process { id: nixWriterProc; running: false }

    function syncToNixTheme() {
        var pyScript = 
            "import sys, re, os\n" +
            "path = os.path.expanduser('~/nix/hosts/common/theme.nix')\n" +
            "if not os.path.exists(path): sys.exit(0)\n" +
            "with open(path, 'r') as f: content = f.read()\n" +
            "b00, b03, b05, b08, b09, b0C, b0D = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7]\n" +
            "f_size, p_pad, b_w, s_w = sys.argv[8], sys.argv[9], sys.argv[10], sys.argv[11]\n" +
            "content = re.sub(r'base00\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base00 = \"{b00}\"', content)\n" +
            "content = re.sub(r'base03\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base03 = \"{b03}\"', content)\n" +
            "content = re.sub(r'base05\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base05 = \"{b05}\"', content)\n" +
            "content = re.sub(r'base08\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base08 = \"{b08}\"', content)\n" +
            "content = re.sub(r'base09\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base09 = \"{b09}\"', content)\n" +
            "content = re.sub(r'base0C\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base0C = \"{b0C}\"', content)\n" +
            "content = re.sub(r'base0D\\s*=\\s*\"#[0-9a-fA-F]{6}\"', f'base0D = \"{b0D}\"', content)\n" +
            "content = re.sub(r'(globalFontSize\\s*=\\s*)\\d+', f'\\g<1>{f_size}', content)\n" +
            "content = re.sub(r'(globalPadding\\s*=\\s*)\\d+', f'\\g<1>{p_pad}', content)\n" +
            "content = re.sub(r'(globalBorderWidth\\s*=\\s*)\\d+', f'\\g<1>{b_w}', content)\n" +
            "content = re.sub(r'(slantWidth\\s*=\\s*)\\d+', f'\\g<1>{s_w}', content)\n" +
            "with open(path, 'w') as f: f.write(content)\n";

        nixWriterProc.running = false;
        nixWriterProc.command = [
            "python3", "-c", pyScript,
            manager.customBase00, manager.customBase03, manager.customBase05,
            manager.customBase08, manager.customBase09, manager.customBase0C, manager.customBase0D,
            manager.globalFontSize.toString(), manager.globalPadding.toString(),
            manager.globalBorderWidth.toString(), manager.slantWidth.toString()
        ];
        nixWriterProc.running = true;
    }

    Process {
        id: loaderProc
        running: true
        command: ["sh", "-c", "F=\"$HOME/.config/quickshell/settings.json\"; [ -f \"$F\" ] && cat \"$F\" || echo '{}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: raw => {
                try {
                    var obj = JSON.parse(raw.trim());
                    if (obj.useStylix !== undefined) manager.useStylix = obj.useStylix;
                    if (obj.animationsEnabled !== undefined) manager.animationsEnabled = obj.animationsEnabled;
                    if (obj.slantStyleMode !== undefined) manager.slantStyleMode = obj.slantStyleMode;
                    if (obj.capsuleSpacing !== undefined) manager.capsuleSpacing = obj.capsuleSpacing;
                    if (obj.globalFontSize !== undefined) manager.globalFontSize = obj.globalFontSize;
                    if (obj.slantWidth !== undefined) manager.slantWidth = obj.slantWidth;
                    if (obj.globalBorderWidth !== undefined) manager.globalBorderWidth = obj.globalBorderWidth;
                    if (obj.globalPadding !== undefined) manager.globalPadding = obj.globalPadding;

                    if (obj.barHeight !== undefined) manager.barHeight = obj.barHeight;
                    if (obj.hardwarePollInterval !== undefined) manager.hardwarePollInterval = obj.hardwarePollInterval;
                    if (obj.launcherWidth !== undefined) manager.launcherWidth = obj.launcherWidth;
                    if (obj.launcherHeight !== undefined) manager.launcherHeight = obj.launcherHeight;
                    if (obj.appItemHeight !== undefined) manager.appItemHeight = obj.appItemHeight;
                    if (obj.appIconSize !== undefined) manager.appIconSize = obj.appIconSize;
                    if (obj.notesFilePath !== undefined) manager.notesFilePath = obj.notesFilePath;
                    if (obj.notifVolume !== undefined) manager.notifVolume = obj.notifVolume;

                    if (obj.notifBaselineY !== undefined) manager.notifBaselineY = obj.notifBaselineY;
                    if (obj.notifStackOverlap !== undefined) manager.notifStackOverlap = obj.notifStackOverlap;
                    if (obj.notifScreenName !== undefined) manager.notifScreenName = obj.notifScreenName;
                    if (obj.magnifierDefaultZoom !== undefined) manager.magnifierDefaultZoom = obj.magnifierDefaultZoom;
                    if (obj.magnifierLensSize !== undefined) manager.magnifierLensSize = obj.magnifierLensSize;
                    if (obj.screenshotSaveDir !== undefined) manager.screenshotSaveDir = obj.screenshotSaveDir;
                    if (obj.defaultWatermarkTag !== undefined) manager.defaultWatermarkTag = obj.defaultWatermarkTag;
                    if (obj.quickshotHistoryLimit !== undefined) manager.quickshotHistoryLimit = obj.quickshotHistoryLimit;
                    if (obj.geminiModelName !== undefined) manager.geminiModelName = obj.geminiModelName;
                    if (obj.clipboardMaxItems !== undefined) manager.clipboardMaxItems = obj.clipboardMaxItems;
                    if (obj.defaultLauncherMode !== undefined) manager.defaultLauncherMode = obj.defaultLauncherMode;
                    if (obj.emailSignature !== undefined) manager.emailSignature = obj.emailSignature;

                    if (obj.activeGpuCard !== undefined) manager.activeGpuCard = obj.activeGpuCard;

                    if (obj.gpu0) {
                        if (obj.gpu0.tempWarn !== undefined) manager.gpu0TempWarn = obj.gpu0.tempWarn;
                        if (obj.gpu0.tempDanger !== undefined) manager.gpu0TempDanger = obj.gpu0.tempDanger;
                        if (obj.gpu0.vramWarn !== undefined) manager.gpu0VramWarn = obj.gpu0.vramWarn;
                        if (obj.gpu0.vramDanger !== undefined) manager.gpu0VramDanger = obj.gpu0.vramDanger;
                    }
                    if (obj.gpu1) {
                        if (obj.gpu1.tempWarn !== undefined) manager.gpu1TempWarn = obj.gpu1.tempWarn;
                        if (obj.gpu1.tempDanger !== undefined) manager.gpu1TempDanger = obj.gpu1.tempDanger;
                        if (obj.gpu1.vramWarn !== undefined) manager.gpu1VramWarn = obj.gpu1.vramWarn;
                        if (obj.gpu1.vramDanger !== undefined) manager.gpu1VramDanger = obj.gpu1.vramDanger;
                    }

                    if (obj.customColors) {
                        if (obj.customColors.base00) manager.customBase00 = obj.customColors.base00;
                        if (obj.customColors.base03) manager.customBase03 = obj.customColors.base03;
                        if (obj.customColors.base05) manager.customBase05 = obj.customColors.base05;
                        if (obj.customColors.base08) manager.customBase08 = obj.customColors.base08;
                        if (obj.customColors.base09) manager.customBase09 = obj.customColors.base09;
                        if (obj.customColors.base0C) manager.customBase0C = obj.customColors.base0C;
                        if (obj.customColors.base0D) manager.customBase0D = obj.customColors.base0D;
                    }

                    if (obj.barLeft && Array.isArray(obj.barLeft) && obj.barLeft.length > 0) manager.barLeftModules = obj.barLeft;
                    if (obj.barCenter && Array.isArray(obj.barCenter) && obj.barCenter.length > 0) manager.barCenterModules = obj.barCenter;
                    if (obj.barRight && Array.isArray(obj.barRight) && obj.barRight.length > 0) manager.barRightModules = obj.barRight;

                    if (obj.capsuleSlants) manager.capsuleSlants = obj.capsuleSlants;
                    if (obj.capsuleDimensions) manager.capsuleDimensions = obj.capsuleDimensions;
                    manager.slantRevision++;
                    if (obj.visibleCapsules) manager.visibleCapsules = obj.visibleCapsules;

                    if (obj.masterVolume !== undefined) manager.masterVolume = obj.masterVolume;
                    if (obj.micVolume !== undefined) manager.micVolume = obj.micVolume;
                    if (obj.micMuted !== undefined) manager.micMuted = obj.micMuted;
                    if (obj.notificationsEnabled !== undefined) manager.notificationsEnabled = obj.notificationsEnabled;
                    if (obj.notifHoldDurationSec !== undefined) manager.notifHoldDurationSec = obj.notifHoldDurationSec;
                    if (obj.enableTts !== undefined) manager.enableTts = obj.enableTts;
                } catch(e) {}
                manager.isLoaded = true;
            }
        }
    }
}
