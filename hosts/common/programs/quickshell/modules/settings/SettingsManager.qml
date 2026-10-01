import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: manager
    
    property string nixThemeFile: (Quickshell.env("HOME") || "") + "/nix/hosts/common/theme.nix"
    
    Process {
        id: themeFinderProc
        running: true
        command: [
            "sh", "-c",
            'if [ -n "$THEME_NIX" ] && [ -f "$THEME_NIX" ]; then echo "$THEME_NIX"; exit 0; fi; ' +
            'for d in "$HOME/.config/quickshell" "$HOME/nix" "$HOME/dotfiles" "$HOME/.config/nix" "/etc/nixos"; do ' +
            '  if [ -d "$d" ]; then ' +
            '    f=$(find "$d" -maxdepth 4 -name "theme.nix" 2>/dev/null | head -n 1); ' +
            '    if [ -n "$f" ] && [ -f "$f" ]; then echo "$f"; exit 0; fi; ' +
            '  fi; ' +
            'done; ' +
            'echo "$HOME/nix/hosts/common/theme.nix"'
        ]
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean.length > 0) manager.nixThemeFile = clean;
            }
        }
    }
    
    property bool useStylix: false
    property bool animationsEnabled: true
    
    property string slantStyleMode: "symmetric"
    property int capsuleSpacing: 2
    property int slantRevision: 0
    property int gpuThresholdRevision: 0
    
    property int globalFontSize: 14
    property int overlayFontSize: 16
    onOverlayFontSizeChanged: queueSave()
    
    // GLOBAL OVERLAY DIMENSIONS
    property int globalOverlayWidth: 840
    onGlobalOverlayWidthChanged: { standaloneRevision++; queueSave(); }
    property int globalOverlayHeight: 650
    onGlobalOverlayHeightChanged: { standaloneRevision++; queueSave(); }
    
    property int slantWidth: 12
    property int globalBorderWidth: 3
    property int globalPadding: 12
    
    // TOP BAR & HARDWARE TIMINGS
    property int barHeight: 42
    property int hardwarePollInterval: 2000
    property int trayCollapseTimeoutSec: 3
    onTrayCollapseTimeoutSecChanged: queueSave()
    
    // LAZY LOADER GRACE TIMEOUT
    property int overlayGraceTimeoutSec: 10
    onOverlayGraceTimeoutSecChanged: queueSave()
    
    // GLOBAL SEARCH & INPUT FIELD HEIGHT
    property int globalFieldHeight: 52
    onGlobalFieldHeightChanged: {
        standaloneRevision++;
        queueSave();
    }
    
    // STORAGE & AUDIO
    property string notesFilePath: Quickshell.env("HOME") + "/Documents/notes.txt"
    property int notifVolume: 80
    
    // OVERLAYS & TOOLS CONFIGURATION
    property int notifBaselineY: 350
    property int notifMarginX: 20
    onNotifMarginXChanged: queueSave()
    property int notifStackOverlap: 25
    property string notifScreenName: ""
    property string rngScreenTarget: "focused"
    onRngScreenTargetChanged: queueSave()
    property string amogusScreenTarget: "1"
    onAmogusScreenTargetChanged: queueSave()
    property real magnifierDefaultZoom: 8.0
    property int magnifierLensSize: 300
    property string screenshotSaveDir: Quickshell.env("HOME") + "/Screenshots"
    property string defaultWatermarkTag: ""
    property int quickshotHistoryLimit: 50
    property string geminiModelName: "gemini-flash-latest"
    property int clipboardMaxItems: 200
    property string defaultLauncherMode: "apps"
    onDefaultLauncherModeChanged: queueSave()
    property string emailSignature: "\n\n--\nSeekers of light..\nBelieve not in justice...\nBelieve not in truth...\nFor they are empty and inconsistent, as are all things..."
    
    // NOTIFICATION CUSTOMIZATION & FILTERS
    property string notifBorderColor: ""
    onNotifBorderColorChanged: queueSave()
    property string notifCustomIcon: ""
    onNotifCustomIconChanged: queueSave()
    property string ttsKeywordsStr: "Apogee, Cageheart, Luster Dawn, Solar Sonata, Vikhlop, Gadren, Parker, urgent, Dad"
    onTtsKeywordsStrChanged: queueSave()
    property string notifExcludedStr: "greenclip, copyq"
    onNotifExcludedStrChanged: queueSave()
    
    readonly property var ttsKeywords: ttsKeywordsStr.split(",").map(s => s.trim()).filter(s => s.length > 0)
    readonly property var notifExcludedStrings: notifExcludedStr.split(",").map(s => s.trim().toLowerCase()).filter(s => s.length > 0)
    
    function isNotificationExcluded(appName, summary, body) {
        var haystack = (appName + " " + summary + " " + body).toLowerCase();
        for (var i = 0; i < notifExcludedStrings.length; i++) {
            if (haystack.includes(notifExcludedStrings[i])) return true;
        }
        return false;
    }
    
    // THEME DEFAULTS
    property string customBase00: "#0f0f0f"
    property string customBase01: "#181825"
    property string customBase02: "#313244"
    property string customBase03: "#003399"
    property string customBase04: "#45475a"
    property string customBase05: "#f7f700"
    property string customBase06: "#cdd6f4"
    property string customBase07: "#b4befe"
    property string customBase08: "#ff0000"
    property string customBase09: "#fe8019"
    property string customBase0A: "#fabd2f"
    property string customBase0B: "#a6adc8"
    property color customBase0C: "#04f100"
    property string customBase0D: "#003399"
    property string customBase0E: "#cba6f7"
    property string customBase0F: "#eba0ac"
    
    function getNixColorBlock() {
        function clean(h) { return String(h).replace("#", ""); }
        return "{\n" +
        "  base00 = \"" + clean(customBase00) + "\";\n" +
        "  base01 = \"" + clean(customBase01) + "\";\n" +
        "  base02 = \"" + clean(customBase02) + "\";\n" +
        "  base03 = \"" + clean(customBase03) + "\";\n" +
        "  base04 = \"" + clean(customBase04) + "\";\n" +
        "  base05 = \"" + clean(customBase05) + "\";\n" +
        "  base06 = \"" + clean(customBase06) + "\";\n" +
        "  base07 = \"" + clean(customBase07) + "\";\n" +
        "  base08 = \"" + clean(customBase08) + "\";\n" +
        "  base09 = \"" + clean(customBase09) + "\";\n" +
        "  base0A = \"" + clean(customBase0A) + "\";\n" +
        "  base0B = \"" + clean(customBase0B) + "\";\n" +
        "  base0C = \"" + clean(customBase0C) + "\";\n" +
        "  base0D = \"" + clean(customBase0D) + "\";\n" +
        "  base0E = \"" + clean(customBase0E) + "\";\n" +
        "  base0F = \"" + clean(customBase0F) + "\";\n" +
        "}";
    }
    
    property var discoveredGpus: []
    property string activeGpuCard: "card0"
    onActiveGpuCardChanged: queueSave()
    
    Process {
        id: gpuScanner
        running: true
        command: [
            "python3", "-c",
            "import os, glob, subprocess, re, json\n" +
            "nv_info = {}\n" +
            "try:\n" +
            "    out = subprocess.check_output(['nvidia-smi', '--query-gpu=index,gpu_name,pci.bus_id', '--format=csv,noheader,nounits'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')\n" +
            "    for line in out.strip().splitlines():\n" +
            "        p = [x.strip() for x in line.split(',')]\n" +
            "        if len(p) >= 3:\n" +
            "            bus_short = p[2].lower().split(':')[-2] + ':' + p[2].lower().split(':')[-1]\n" +
            "            nv_info[bus_short] = (p[0], p[1])\n" +
            "except: pass\n" +
            "def get_vram_gb(dev_path):\n" +
            "    try:\n" +
            "        v = int(open(os.path.join(dev_path, 'mem_info_vram_total')).read().strip())\n" +
            "        return round(v / 1073741824)\n" +
            "    except: return 0\n" +
            "def query_udev_name(cid):\n" +
            "    subsys, model = '', ''\n" +
            "    try:\n" +
            "        out = subprocess.check_output(['udevadm', 'info', '-q', 'property', '-p', f'/sys/class/drm/{cid}/device'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')\n" +
            "        for line in out.splitlines():\n" +
            "            if line.startswith('ID_PCI_SUBFSYS_MODEL_FROM_DATABASE='): subsys = line.split('=', 1)[1].strip()\n" +
            "            elif line.startswith('ID_MODEL_FROM_DATABASE='): model = line.split('=', 1)[1].strip()\n" +
            "    except: pass\n" +
            "    val = subsys or model\n" +
            "    m = re.search(r'\\[(.*?)\\]', val)\n" +
            "    return m.group(1) if m else val\n" +
            "def clean_specific_name(raw, vram_gb):\n" +
            "    if not raw: return 'GPU', 'GPU'\n" +
            "    name = raw\n" +
            "    if '7900' in name:\n" +
            "        name = 'RX 7900 XTX' if vram_gb >= 22 else 'RX 7900 XT'\n" +
            "    elif '6400' in name or '6500' in name:\n" +
            "        name = 'RX 6400' if vram_gb <= 4 else 'RX 6500 XT'\n" +
            "    elif '6600' in name:\n" +
            "        name = 'RX 6600 XT' if 'xt' in name.lower() else 'RX 6600'\n" +
            "    elif '6700' in name:\n" +
            "        name = 'RX 6700 XT'\n" +
            "    elif '6800' in name:\n" +
            "        name = 'RX 6800 XT'\n" +
            "    elif '/' in name:\n" +
            "        name = name.split('/')[0].strip()\n" +
            "    short = re.sub(r'^(NVIDIA\\s+GeForce\\s+|NVIDIA\\s+|AMD\\s+Radeon\\s+|Radeon\\s+)', '', name, flags=re.I).strip() or name\n" +
            "    return name, short\n" +
            "gpus = []\n" +
            "for c in sorted(glob.glob('/sys/class/drm/card[0-9]')):\n" +
            "    cid = os.path.basename(c)\n" +
            "    dev = os.path.join(c, 'device')\n" +
            "    if not os.path.isdir(dev): continue\n" +
            "    vendor, device_id = '', ''\n" +
            "    try: vendor = open(os.path.join(dev, 'vendor')).read().strip().replace('0x', '').lower()\n" +
            "    except: pass\n" +
            "    try: device_id = open(os.path.join(dev, 'device')).read().strip().replace('0x', '').lower()\n" +
            "    except: pass\n" +
            "    pci_link = os.path.basename(os.path.realpath(dev)).lower()\n" +
            "    bus_short = pci_link.split(':')[-2] + ':' + pci_link.split(':')[-1] if ':' in pci_link else ''\n" +
            "    vram = get_vram_gb(dev)\n" +
            "    raw_name, nv_idx, is_nv = '', '0', (vendor == '10de')\n" +
            "    if is_nv and bus_short in nv_info:\n" +
            "        nv_idx, raw_name = nv_info[bus_short]\n" +
            "    elif is_nv and nv_info:\n" +
            "        nv_idx, raw_name = list(nv_info.values())[0]\n" +
            "    if not raw_name: raw_name = query_udev_name(cid)\n" +
            "    full_name, short_name = clean_specific_name(raw_name, vram)\n" +
            "    rnodes = sorted(glob.glob(os.path.join(dev, 'drm', 'renderD*')))\n" +
            "    render = os.path.basename(rnodes[0]) if rnodes else 'renderD128'\n" +
            "    is_discrete = is_nv or (vendor == '1002' and vram >= 6)\n" +
            "    gpus.append({'id': cid, 'vendor': vendor, 'device': device_id, 'name': short_name, 'fullName': full_name, 'render': render, 'nv_index': nv_idx, 'vram_gb': vram, 'is_discrete': is_discrete})\n" +
            "gpus.sort(key=lambda x: (0 if x.get('is_discrete') else 1, -x.get('vram_gb', 0)))\n" +
            "print(json.dumps(gpus))\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(text.trim());
                    if (Array.isArray(list) && list.length > 0) {
                        manager.discoveredGpus = list;
                    }
                } catch(e) {}
            }
        }
    }
    
    readonly property var availableGpuCards: (discoveredGpus && discoveredGpus.length > 0)
    ? discoveredGpus
    : [
        { id: "card0", vendor: "", name: "GPU 0", render: "renderD128", nv_index: "0" },
        { id: "card1", vendor: "", name: "GPU 1", render: "renderD129", nv_index: "0" }
    ]
    
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
    
    // STANDALONE WINDOW RESIZING & LIFECYCLE REGISTRY
    property string previewWindow: ""
    property var standaloneWindows: ({})
    property int standaloneRevision: 0
    
    function getWindowWidth(idStr, defaultW) {
        var _rev = manager.standaloneRevision;
        if (standaloneWindows && standaloneWindows[idStr] && standaloneWindows[idStr].width > 0) {
            return standaloneWindows[idStr].width;
        }
        return manager.globalOverlayWidth || defaultW || 840;
    }
    
    function getWindowHeight(idStr, defaultH) {
        var _rev = manager.standaloneRevision;
        if (standaloneWindows && standaloneWindows[idStr] && standaloneWindows[idStr].height > 0) {
            return standaloneWindows[idStr].height;
        }
        return manager.globalOverlayHeight || defaultH || 650;
    }
    
    function getWindowFieldHeight(idStr, defaultFH) {
        var _rev = manager.standaloneRevision;
        if (standaloneWindows && standaloneWindows[idStr] && standaloneWindows[idStr].fieldHeight > 0) {
            return standaloneWindows[idStr].fieldHeight;
        }
        return manager.globalFieldHeight || defaultFH || 52;
    }
    
    function getWindowIconSize(idStr, defaultIS) {
        var _rev = manager.standaloneRevision;
        if (standaloneWindows && standaloneWindows[idStr] && standaloneWindows[idStr].iconSize > 0) {
            return standaloneWindows[idStr].iconSize;
        }
        return defaultIS || 38;
    }
    
    function getWindowImageSize(idStr, defaultIS) {
        var _rev = manager.standaloneRevision;
        if (standaloneWindows && standaloneWindows[idStr] && standaloneWindows[idStr].imageSize > 0) {
            return standaloneWindows[idStr].imageSize;
        }
        return defaultIS || 80;
    }
    
    function getWindowLoadPolicy(idStr, defaultPolicy) {
        var _rev = manager.standaloneRevision;
        if (standaloneWindows && standaloneWindows[idStr] && standaloneWindows[idStr].loadPolicy) {
            return standaloneWindows[idStr].loadPolicy;
        }
        return defaultPolicy || "lazy";
    }
    
    function setWindowLoadPolicy(idStr, policy) {
        setWindowProp(idStr, "loadPolicy", policy);
    }
    
    function setWindowProp(idStr, prop, val) {
        var copy = Object.assign({}, standaloneWindows);
        if (!copy[idStr]) copy[idStr] = {};
        copy[idStr][prop] = (typeof val === "number") ? Math.round(val) : val;
        standaloneWindows = copy;
        standaloneRevision++;
        saveToDisk();
    }
    
    // BAR CAPSULES CONFIGURATION
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
    
    property var capsuleSlants: ({})
    function getModuleSlant(idStr, section) {
        var _rev = manager.slantRevision;
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
    
    property var barLeftModules: ["calendar", "music", "alarm", "weather", "unified", "notify"]
    property var barCenterModules: ["audio", "clock", "mic"]
    property var barRightModules: ["tray", "ram", "gpu", "cpu", "net", "battery"]
    
    function getLeftList() { return barLeftModules.length > 0 ? barLeftModules : ["calendar", "music", "alarm", "weather", "unified", "notify"]; }
    function getCenterList() { return barCenterModules.length > 0 ? barCenterModules : ["audio", "clock", "mic"]; }
    function getRightList() { return barRightModules.length > 0 ? barRightModules : ["tray", "ram", "gpu", "cpu", "net", "battery"]; }
    
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
    
    property int masterVolume: 80
    property int micVolume: 100
    property bool micMuted: false
    function updateMicFromSystem(muted, vol) {
        micMuted = muted;
        if (vol !== undefined && vol >= 0) micVolume = vol;
    }
    
    property bool notificationsEnabled: true
    property int notifHoldDurationSec: 5
    property bool enableTts: true
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
    
    Process { id: writerProc; running: false }
    
    function saveToDisk() {
        var data = {
            "useStylix": manager.useStylix,
            "animationsEnabled": manager.animationsEnabled,
            "slantStyleMode": manager.slantStyleMode,
            "capsuleSpacing": manager.capsuleSpacing,
            "globalFontSize": manager.globalFontSize,
            "overlayFontSize": manager.overlayFontSize,
            "globalOverlayWidth": manager.globalOverlayWidth,
            "globalOverlayHeight": manager.globalOverlayHeight,
            "globalFieldHeight": manager.globalFieldHeight,
            "slantWidth": manager.slantWidth,
            "globalBorderWidth": manager.globalBorderWidth,
            "globalPadding": manager.globalPadding,
            "barHeight": manager.barHeight,
            "hardwarePollInterval": manager.hardwarePollInterval,
            "trayCollapseTimeoutSec": manager.trayCollapseTimeoutSec,
            "overlayGraceTimeoutSec": manager.overlayGraceTimeoutSec,
            "notesFilePath": manager.notesFilePath,
            "notifVolume": manager.notifVolume,
            "notifBaselineY": manager.notifBaselineY,
            "notifMarginX": manager.notifMarginX,
            "notifStackOverlap": manager.notifStackOverlap,
            "notifScreenName": manager.notifScreenName,
            "notifBorderColor": manager.notifBorderColor,
            "notifCustomIcon": manager.notifCustomIcon,
            "ttsKeywordsStr": manager.ttsKeywordsStr,
            "notifExcludedStr": manager.notifExcludedStr,
            "rngScreenTarget": manager.rngScreenTarget,
            "amogusScreenTarget": manager.amogusScreenTarget,
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
                "base00": manager.customBase00, "base01": manager.customBase01, "base02": manager.customBase02, "base03": manager.customBase03,
                "base04": manager.customBase04, "base05": manager.customBase05, "base06": manager.customBase06, "base07": manager.customBase07,
                "base08": manager.customBase08, "base09": manager.customBase09, "base0A": manager.customBase0A, "base0B": manager.customBase0B,
                "base0C": manager.customBase0C, "base0D": manager.customBase0D, "base0E": manager.customBase0E, "base0F": manager.customBase0F
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
            "standaloneWindows": manager.standaloneWindows,
            "visibleCapsules": manager.visibleCapsules
        };
        
        writerProc.command = [
            "python3", "-c",
            "import sys, os\n" +
            "f_path = os.path.expanduser('~/.config/quickshell/settings.json')\n" +
            "os.makedirs(os.path.dirname(f_path), exist_ok=True)\n" +
            "tmp_path = f_path + '.tmp'\n" +
            "with open(tmp_path, 'w') as f: f.write(sys.argv[1])\n" +
            "os.replace(tmp_path, f_path)\n",
            JSON.stringify(data)
        ];
        writerProc.running = true;
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
                    if (obj.overlayFontSize !== undefined) manager.overlayFontSize = obj.overlayFontSize;
                    if (obj.globalOverlayWidth !== undefined) manager.globalOverlayWidth = obj.globalOverlayWidth;
                    if (obj.globalOverlayHeight !== undefined) manager.globalOverlayHeight = obj.globalOverlayHeight;
                    if (obj.globalFieldHeight !== undefined) manager.globalFieldHeight = obj.globalFieldHeight;
                    if (obj.slantWidth !== undefined) manager.slantWidth = obj.slantWidth;
                    if (obj.globalBorderWidth !== undefined) manager.globalBorderWidth = obj.globalBorderWidth;
                    if (obj.globalPadding !== undefined) manager.globalPadding = obj.globalPadding;
                    if (obj.barHeight !== undefined) manager.barHeight = obj.barHeight;
                    if (obj.hardwarePollInterval !== undefined) manager.hardwarePollInterval = obj.hardwarePollInterval;
                    if (obj.trayCollapseTimeoutSec !== undefined) manager.trayCollapseTimeoutSec = obj.trayCollapseTimeoutSec;
                    if (obj.overlayGraceTimeoutSec !== undefined) manager.overlayGraceTimeoutSec = obj.overlayGraceTimeoutSec;
                    if (obj.notesFilePath !== undefined) manager.notesFilePath = obj.notesFilePath;
                    if (obj.notifVolume !== undefined) manager.notifVolume = obj.notifVolume;
                    if (obj.notifBaselineY !== undefined) manager.notifBaselineY = obj.notifBaselineY;
                    if (obj.notifMarginX !== undefined) manager.notifMarginX = obj.notifMarginX;
                    if (obj.notifStackOverlap !== undefined) manager.notifStackOverlap = obj.notifStackOverlap;
                    if (obj.notifScreenName !== undefined) manager.notifScreenName = obj.notifScreenName;
                    if (obj.notifBorderColor !== undefined) manager.notifBorderColor = obj.notifBorderColor;
                    if (obj.notifCustomIcon !== undefined) manager.notifCustomIcon = obj.notifCustomIcon;
                    if (obj.ttsKeywordsStr !== undefined) manager.ttsKeywordsStr = obj.ttsKeywordsStr;
                    if (obj.notifExcludedStr !== undefined) manager.notifExcludedStr = obj.notifExcludedStr;
                    if (obj.rngScreenTarget !== undefined) manager.rngScreenTarget = obj.rngScreenTarget;
                    if (obj.amogusScreenTarget !== undefined) manager.amogusScreenTarget = obj.amogusScreenTarget;
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
                        if (obj.customColors.base01) manager.customBase01 = obj.customColors.base01;
                        if (obj.customColors.base02) manager.customBase02 = obj.customColors.base02;
                        if (obj.customColors.base03) manager.customBase03 = obj.customColors.base03;
                        if (obj.customColors.base04) manager.customBase04 = obj.customColors.base04;
                        if (obj.customColors.base05) manager.customBase05 = obj.customColors.base05;
                        if (obj.customColors.base06) manager.customBase06 = obj.customColors.base06;
                        if (obj.customColors.base07) manager.customBase07 = obj.customColors.base07;
                        if (obj.customColors.base08) manager.customBase08 = obj.customColors.base08;
                        if (obj.customColors.base09) manager.customBase09 = obj.customColors.base09;
                        if (obj.customColors.base0A) manager.customBase0A = obj.customColors.base0A;
                        if (obj.customColors.base0B) manager.customBase0B = obj.customColors.base0B;
                        if (obj.customColors.base0C) manager.customBase0C = obj.customColors.base0C;
                        if (obj.customColors.base0D) manager.customBase0D = obj.customColors.base0D;
                        if (obj.customColors.base0E) manager.customBase0E = obj.customColors.base0E;
                        if (obj.customColors.base0F) manager.customBase0F = obj.customColors.base0F;
                    }
                    
                    if (obj.barLeft && Array.isArray(obj.barLeft)) manager.barLeftModules = obj.barLeft;
                    if (obj.barCenter && Array.isArray(obj.barCenter)) manager.barCenterModules = obj.barCenter;
                    if (obj.barRight && Array.isArray(obj.barRight)) manager.barRightModules = obj.barRight;
                    
                    if (obj.capsuleSlants) manager.capsuleSlants = obj.capsuleSlants;
                    if (obj.capsuleDimensions) manager.capsuleDimensions = obj.capsuleDimensions;
                    if (obj.standaloneWindows) manager.standaloneWindows = obj.standaloneWindows;
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
    
    Process { id: stylixSaverProc; running: false }
    
    function saveColorToStylix(propName, hexStr) {
        var baseKey = propName.replace(/^customB/, "b");
        if (!baseKey.startsWith("base")) baseKey = "base05";
        
        stylixSaverProc.command = [
            "python3", "-c",
            "import os, re, sys, subprocess\n" +
            "prop = sys.argv[1]\n" +
            "hex_val = sys.argv[2]\n" +
            "clean_hex = hex_val.replace('#', '')\n" +
            "theme_nix = os.path.expanduser(sys.argv[3])\n" +
            "theme_qml = os.path.expanduser(sys.argv[4])\n" +
            "updated_nix = False\n" +
            "if os.path.isfile(theme_nix):\n" +
            "    try:\n" +
            "        with open(theme_nix, 'r') as f: content = f.read()\n" +
            "        new_content = re.sub(r'(' + prop + r'\\s*=\\s*\"#?)[^\"]+(\";)', r'\\g<1>' + clean_hex + r'\\g<2>', content)\n" +
            "        if new_content != content:\n" +
            "            with open(theme_nix, 'w') as f: f.write(new_content)\n" +
            "            updated_nix = True\n" +
            "    except Exception as e: pass\n" +
            "updated_qml = False\n" +
            "if os.path.isfile(theme_qml):\n" +
            "    try:\n" +
            "        with open(theme_qml, 'r') as f: qcontent = f.read()\n" +
            "        new_qcontent = re.sub(r'(property\\s+color\\s+' + prop + r'\\s*:\\s*\")[^\"]+(\")', r'\\g<1>#' + clean_hex + r'\\g<2>', qcontent)\n" +
            "        if new_qcontent != qcontent:\n" +
            "            with open(theme_qml, 'w') as f: f.write(new_qcontent)\n" +
            "            updated_qml = True\n" +
            "    except Exception as e: pass\n" +
            "msg = f'Saved {prop} (#{clean_hex})'\n" +
            "if updated_nix and updated_qml: detail = 'Updated theme.nix and Theme.qml'\n" +
            "elif updated_nix: detail = 'Updated theme.nix'\n" +
            "elif updated_qml: detail = 'Updated Theme.qml'\n" +
            "else: detail = f'Saved locally ({theme_nix} not found)'\n" +
            "subprocess.run(['notify-send', '-a', 'Settings', '💾 Saved to Stylix', f'{msg}: {detail}'])\n",
            baseKey,
            hexStr,
            manager.nixThemeFile,
            Quickshell.shellDir + "/Theme.qml"
        ];
        stylixSaverProc.running = true;
    }
}
