import "../../common/Utils.js" as Utils
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../style"

Item {
    id: musicBox

    // ──────────────────────────────────────────────────────────────
    // Theme
    // ──────────────────────────────────────────────────────────────
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property int themeBorderWidth: (shell && shell.theme && typeof shell.theme.globalBorderWidth !== "undefined") ? shell.theme.globalBorderWidth : 3
    readonly property var themeBase00: (shell && shell.theme && shell.theme.base00 !== undefined) ? shell.theme.base00 : "black"
    readonly property var themeBase02: (shell && shell.theme && shell.theme.base02 !== undefined) ? shell.theme.base02 : "#222222"
    readonly property var themeBase03: (shell && shell.theme && shell.theme.base03 !== undefined) ? shell.theme.base03 : "#333333"
    readonly property var themeBase05: (shell && shell.theme && shell.theme.base05 !== undefined) ? shell.theme.base05 : "yellow"
    readonly property var themeBase0C: (shell && shell.theme && shell.theme.base0C !== undefined) ? shell.theme.base0C : "#04f100"

    // ──────────────────────────────────────────────────────────────
    // Layout properties
    // ──────────────────────────────────────────────────────────────
    property int tooltipHeight: 420
    property int tooltipCollapsedWidth: 179
    property int tooltipExpandedWidth: 430
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: musicBox.themeSlantWidth
    property var barWindow: null
    property string moduleName: "music"

    // Maximum characters to show in the bar title (0 disables truncation)
    property int maxTitleLength: 15

    // ──────────────────────────────────────────────────────────────
    // MPRIS player selection
    // Picks the first playing player, else the first controllable one.
    // ──────────────────────────────────────────────────────────────
    readonly property var activePlayer: {
        var players = Mpris.players ? Mpris.players.values : []
        var fallback = null
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (!p.canControl) continue
                if (p.isPlaying) return p
                    if (!fallback) fallback = p
        }
        return fallback
    }

    readonly property bool playerAvailable: activePlayer !== null

    // ──────────────────────────────────────────────────────────────
    // Derived track info (read from MPRIS)
    // ──────────────────────────────────────────────────────────────
    property string trackStr: {
        if (!playerAvailable) return "No Track"
            var title = activePlayer.trackTitle || "No Track"
            if (musicBox.maxTitleLength > 0 && title.length > musicBox.maxTitleLength) {
                return title.slice(0, musicBox.maxTitleLength).trim() + "…"
            }
            return title
    }
    property string tooltipTitle: {
        if (!playerAvailable) return "No Title Playing"
            return activePlayer.trackTitle || "No Title Playing"
    }
    property string tooltipArtist: {
        if (!playerAvailable) return "No Artist Data"
            return activePlayer.trackArtist || "Unknown Artist"
    }
    property string tooltipAlbum: {
        if (!playerAvailable) return ""
            return activePlayer.trackAlbum || ""
    }
    property string playbackState: {
        if (!playerAvailable) return "stop"
            switch (activePlayer.playbackState) {
                case MprisPlaybackState.Playing: return "play"
                case MprisPlaybackState.Paused:  return "pause"
                default:                         return "stop"
            }
    }

    // Track count — MPRIS doesn't expose this; we keep a placeholder.
    property string trackCountStr: ""

    // Position / duration (seconds, from MPRIS)
    property real elapsedSeconds: playerAvailable ? activePlayer.position : 0
    property real totalSeconds:   playerAvailable ? activePlayer.length   : 0

    // Volume — MPRIS exposes 0.0–1.0
    property real currentVolume: playerAvailable && activePlayer.volumeSupported
    ? Math.round(activePlayer.volume * 100) : 0

    // ──────────────────────────────────────────────────────────────
    // UI state
    // ──────────────────────────────────────────────────────────────
    property bool popupActive: false
    property bool confirmDeleteMode: false
    property string currentFile: ""

    // ──────────────────────────────────────────────────────────────
    // Position refresh
    // ──────────────────────────────────────────────────────────────
    Timer {
        interval: 1000
        repeat: true
        running: musicBox.playerAvailable && musicBox.playbackState === "play"
        onTriggered: if (musicBox.activePlayer) musicBox.activePlayer.positionChanged()
    }

    // ──────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────
    function formatTime(secs) {
        return Utils.formatDuration(secs, false)
    }

    function sendMpdCommand(cmd) {
        if (!cmd) return
            Quickshell.execDetached(["sh", "-c",
                                    "printf '%s\\n' \"$1\" | mpc --quiet",
                                    "sh", cmd.replace(/\\n/g, "\n").trim()
            ])
    }

    // ──────────────────────────────────────────────────────────────
    // Folder button helper: ask mpc for the current file, open its dir.
    // ──────────────────────────────────────────────────────────────
    Process {
        id: getFileProcess
        running: false
        command: ["mpc", "current", "--format", "%file%"]
        stdout: StdioCollector {
            onStreamFinished: {
                var file = text.trim()
                if (!file) {
                    Quickshell.execDetached(["nemo", "$HOME/Music"])
                    return
                }
                musicBox.currentFile = file
                Quickshell.execDetached(["sh", "-c",
                                        'f="$HOME/Music/$1"; ' +
                                        'if [ -d "$f" ]; then d="$f"; ' +
                                        'elif [ -e "$f" ]; then d="$(dirname "$f")"; ' +
                                        'else d="$HOME/Music"; fi; ' +
                                        'exec nemo "$d" 2>/dev/null',
                                        "sh", file
                ])
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Bar label
    // ──────────────────────────────────────────────────────────────
    implicitWidth: Math.max(180, musicText.implicitWidth + bg.leftPadding + bg.rightPadding + 16)
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight
        slantWidth: musicBox.slantWidth
    }

    Text {
        id: musicText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        color: themeBase05
        text: musicBox.trackStr
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }

    TapHandler {
        onTapped: {
            musicBox.popupActive = !musicBox.popupActive
            if (!musicBox.popupActive) {
                musicBox.confirmDeleteMode = false
            } else if (musicBox.activePlayer) {
                musicBox.activePlayer.positionChanged()
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Tooltip / popup
    // ──────────────────────────────────────────────────────────────
    SlantedTooltip {
        id: musicTooltip
        moduleItem: musicBox
        barWindow: musicBox.barWindow
        tooltipActive: musicBox.popupActive
        pin: musicBox.popupActive
        alignSide: "Left"
        tooltipHeight: musicBox.tooltipHeight
        collapsedCoreWidth: musicBox.tooltipCollapsedWidth
        expandedCoreWidth: musicBox.tooltipExpandedWidth
        topOffset: musicBox.tooltipTopOffset
        rightOffset: musicBox.tooltipRightOffset
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight

        Item {
            id: containerWrapper
            anchors.fill: parent
            readonly property real slantRatio: musicTooltip.tooltipSlantWidth / musicTooltip.tooltipHeight

            // ── 1. TRACK DETAILS ──────────────────────────────────
            Item {
                id: trackCard
                y: 40
                x: musicTooltip.slantX(y) + 36
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                height: 105

                SlantedBox {
                    id: innerCardBg
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * containerWrapper.slantRatio
                    borderColor: themeBase05
                    color: "transparent"
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - (parent.height * containerWrapper.slantRatio) - 20
                    spacing: 4

                    Text {
                        width: parent.width
                        text: musicBox.tooltipTitle
                        font.family: themeFontFamily
                        font.pixelSize: 18
                        font.bold: true
                        color: themeBase05
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: musicBox.tooltipArtist
                        font.family: themeFontFamily
                        font.pixelSize: 15
                        color: themeBase05
                        opacity: 0.8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: musicBox.tooltipAlbum !== ""
                        text: musicBox.tooltipAlbum
                        font.family: themeFontFamily
                        font.pixelSize: 13
                        color: themeBase05
                        opacity: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }

            // ── 2. SEEK SLIDER ────────────────────────────────────
            Row {
                y: 165
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 8

                Text {
                    text: musicBox.formatTime(musicBox.elapsedSeconds)
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: seekSlider
                    width: parent.width - 90
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: musicBox.playerAvailable
                    && musicBox.activePlayer.canSeek
                    && musicBox.activePlayer.positionSupported
                    from: 0
                    to: musicBox.totalSeconds > 0 ? musicBox.totalSeconds : 100
                    value: musicBox.elapsedSeconds

                    background: SlantedBox {
                        implicitHeight: 8
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 10
                        color: themeBase03; borderColor: "transparent"
                        SlantedBox {
                            height: parent.height
                            width: Math.max(10, seekSlider.visualPosition * parent.width)
                            slantLeft: "Left"; slantRight: "Left"; slantWidth: 10
                            color: themeBase05; borderColor: "transparent"
                        }
                    }
                    handle: SlantedBox {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        implicitWidth: 14; implicitHeight: 14
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 6
                        color: themeBase05; borderColor: themeBase05
                    }
                    onMoved: {
                        if (!musicBox.activePlayer || !musicBox.activePlayer.canSeek) return
                            musicBox.activePlayer.position = value
                    }
                }

                Text {
                    text: musicBox.formatTime(musicBox.totalSeconds)
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ── 3. VOLUME SLIDER ──────────────────────────────────
            Row {
                y: 215
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 8

                Text {
                    text: "VOL"
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: volSlider
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: musicBox.playerAvailable && musicBox.activePlayer.volumeSupported
                    from: 0; to: 100
                    value: musicBox.currentVolume
                    onMoved: {
                        if (!musicBox.activePlayer || !musicBox.activePlayer.volumeSupported) return
                            musicBox.activePlayer.volume = value / 100.0
                    }

                    background: SlantedBox {
                        implicitHeight: 8
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 10
                        color: themeBase03; borderColor: "transparent"
                        SlantedBox {
                            height: parent.height
                            width: Math.max(10, volSlider.visualPosition * parent.width)
                            slantLeft: "Left"; slantRight: "Left"; slantWidth: 10
                            color: themeBase05; borderColor: "transparent"
                        }
                    }
                    handle: SlantedBox {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 14; implicitHeight: 14
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 6
                        color: themeBase05; borderColor: themeBase05
                    }
                }

                Text {
                    text: Math.round(volSlider.value) + "%"
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ── 4. PLAYBACK CONTROLS ──────────────────────────────
            Row {
                y: 275
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 12

                Item { width: Math.max(0, (parent.width - 324) / 2); height: 42 }

                Item {
                    width: 100; height: 42
                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "⏮"; font.pixelSize: 20; color: themeBase05
                        opacity: musicBox.playerAvailable && musicBox.activePlayer.canGoPrevious ? 1.0 : 0.4
                    }
                    TapHandler {
                        onTapped: if (musicBox.activePlayer && musicBox.activePlayer.canGoPrevious)
                        musicBox.activePlayer.previous()
                    }
                }

                Item {
                    width: 100; height: 42
                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text {
                        anchors.centerIn: parent
                        text: musicBox.playbackState === "play" ? "⏸" : "⏯"
                        font.pixelSize: 20; color: themeBase05
                        opacity: musicBox.playerAvailable && musicBox.activePlayer.canTogglePlaying ? 1.0 : 0.4
                    }
                    TapHandler {
                        onTapped: if (musicBox.activePlayer && musicBox.activePlayer.canTogglePlaying)
                        musicBox.activePlayer.togglePlaying()
                    }
                }

                Item {
                    width: 100; height: 42
                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "⏭"; font.pixelSize: 20; color: themeBase05
                        opacity: musicBox.playerAvailable && musicBox.activePlayer.canGoNext ? 1.0 : 0.4
                    }
                    TapHandler {
                        onTapped: if (musicBox.activePlayer && musicBox.activePlayer.canGoNext)
                        musicBox.activePlayer.next()
                    }
                }
            }

            // ── 5. UTILITY CONTROLS ───────────────────────────────
            Row {
                y: 335
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 12

                Item {
                    width: {
                        var totalBtnW = musicBox.confirmDeleteMode ? 240 : 180
                        return Math.max(0, (parent.width - totalBtnW) / 2)
                    }
                    height: 38
                }

                // ── Open Folder ──────────────────────────────────
                Item {
                    width: 80; height: 38
                    visible: !musicBox.confirmDeleteMode
                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "📂"; font.pixelSize: 18; color: themeBase05
                    }
                    TapHandler {
                        onTapped: {
                            getFileProcess.running = true
                            musicBox.popupActive = false
                        }
                    }
                }

                // ── Delete (from playlist only — safer) ──────────
                Item {
                    width: musicBox.confirmDeleteMode ? 140 : 80
                    height: 38
                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        borderColor: musicBox.confirmDeleteMode ? "#ffffff" : themeBase05
                        color: musicBox.confirmDeleteMode ? "#ff5555" : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: musicBox.confirmDeleteMode ? "⚠️ Sure?" : "🗑️"
                        font.pixelSize: musicBox.confirmDeleteMode ? 14 : 20
                        font.bold: musicBox.confirmDeleteMode
                        color: musicBox.confirmDeleteMode ? "#ffffff" : themeBase05
                    }
                    TapHandler {
                        onTapped: {
                            if (!musicBox.confirmDeleteMode) {
                                musicBox.confirmDeleteMode = true
                            } else {
                                Quickshell.execDetached(["mpc", "del", "0"])
                                musicBox.confirmDeleteMode = false
                                if (musicBox.activePlayer) musicBox.activePlayer.next()
                            }
                        }
                    }
                }

                // ── Cancel ──────────────────────────────────────
                Item {
                    width: 70; height: 38
                    visible: musicBox.confirmDeleteMode
                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "No"; font.pixelSize: 16; color: themeBase05
                    }
                    TapHandler {
                        onTapped: {
                            musicBox.popupActive = false
                            musicBox.confirmDeleteMode = false
                        }
                    }
                }
            }
        }
    }
}
