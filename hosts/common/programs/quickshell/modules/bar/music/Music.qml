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

    property int tooltipHeight: 460
    property int tooltipCollapsedWidth: 179
    property int tooltipExpandedWidth: 460
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    // Dynamic slanting bound to Bar Section & Settings rules
    property string slantLeft: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(musicBox.moduleName, "left") === "right" ? "Right" : "Left") : "Left"
    property string slantRight: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(musicBox.moduleName, "left") === "right" ? "Right" : "Left") : "Left"
    property int slantWidth: musicBox.themeSlantWidth
    property var barWindow: null
    property string moduleName: "music"

    property int maxTitleLength: 15

    function getPlayerCategory(player) {
        if (!player) return "unknown";
        var id = ((player.identity || "") + " " + (player.desktopEntry || "") + " " + (player.busName || "")).toLowerCase();
        if (id.includes("spotify") || id.includes("ncspot") || id.includes("spotifyd")) return "spotify";
        if (id.includes("firefox") || id.includes("chromium") || id.includes("chrome") || id.includes("brave") || id.includes("zen") || id.includes("librewolf") || id.includes("vivaldi") || id.includes("edge")) return "browser";
        return "local";
    }

    readonly property var activePlayer: {
        var players = Mpris.players ? Mpris.players.values : [];
        var fallback = null;
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (!p.canControl && !p.isPlaying) continue;

            var cat = getPlayerCategory(p);
            if (cat === "local" && shell && shell.settingsManager && !shell.settingsManager.mprisWatchLocal) continue;
            if (cat === "spotify" && shell && shell.settingsManager && !shell.settingsManager.mprisWatchSpotify) continue;
            if (cat === "browser" && shell && shell.settingsManager && !shell.settingsManager.mprisWatchBrowser) continue;

            if (p.isPlaying) return p;
            if (!fallback) fallback = p;
        }
        return fallback;
    }

    readonly property bool playerAvailable: activePlayer !== null

    property string trackStr: {
        if (!playerAvailable) return "No Track";
        var title = activePlayer.trackTitle || "No Track";
        if (musicBox.maxTitleLength > 0 && title.length > musicBox.maxTitleLength) {
            return title.slice(0, musicBox.maxTitleLength).trim() + "…";
        }
        return title;
    }
    property string tooltipTitle: playerAvailable ? (activePlayer.trackTitle || "No Title Playing") : "No Title Playing"
    property string tooltipArtist: playerAvailable ? (activePlayer.trackArtist || "Unknown Artist") : "No Artist Data"
    property string tooltipAlbum: playerAvailable ? (activePlayer.trackAlbum || "") : ""
    property string playbackState: {
        if (!playerAvailable) return "stop";
        switch (activePlayer.playbackState) {
            case MprisPlaybackState.Playing: return "play";
            case MprisPlaybackState.Paused:  return "pause";
            default:                         return "stop";
        }
    }

    property real elapsedSeconds: playerAvailable ? activePlayer.position : 0
    property real totalSeconds: playerAvailable ? activePlayer.length : 0
    property real currentVolume: playerAvailable && activePlayer.volumeSupported ? Math.round(activePlayer.volume * 100) : 0

    property bool popupActive: false
    property bool confirmDeleteMode: false

    Timer {
        interval: 1000; repeat: true
        running: musicBox.playerAvailable && musicBox.playbackState === "play"
        onTriggered: if (musicBox.activePlayer) musicBox.activePlayer.positionChanged()
    }

    function formatTime(secs) { return Utils.formatDuration(secs, false); }

    function openMusicDirectory() {
        var rawUrl = (musicBox.activePlayer && musicBox.activePlayer.metadata && musicBox.activePlayer.metadata["xesam:url"])
            ? musicBox.activePlayer.metadata["xesam:url"]
            : "";

        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--quiet",
            "bash", "-c",
            'url="$1"; target=""; ' +
            'if [ -n "$url" ] && [[ "$url" == file://* ]]; then ' +
            '    clean=$(python3 -c "import urllib.parse, sys; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "${url#file://}"); ' +
            '    if [ -e "$clean" ]; then target="$clean"; fi; ' +
            'fi; ' +
            'if [ -z "$target" ]; then ' +
            '    mpc_file=$(mpc current -f "%file%" 2>/dev/null); ' +
            '    if [ -n "$mpc_file" ]; then ' +
            '        mpd_dir=$(grep -E "^\\s*music_directory" ~/.config/mpd/mpd.conf 2>/dev/null | awk "{print \\$2}" | tr -d "\\\"\\\'"); ' +
            '        [ -z "$mpd_dir" ] && mpd_dir="$HOME/Music"; ' +
            '        eval mpd_dir_expanded="$mpd_dir"; ' +
            '        if [ -e "$mpd_dir_expanded/$mpc_file" ]; then target="$mpd_dir_expanded/$mpc_file"; ' +
            '        elif [ -e "$HOME/Music/$mpc_file" ]; then target="$HOME/Music/$mpc_file"; fi; ' +
            '    fi; ' +
            'fi; ' +
            'dir=""; ' +
            'if [ -d "$target" ]; then dir="${target#file://}"; ' +
            'elif [ -f "$target" ]; then dir="$(dirname "${target#file://}")"; ' +
            'else dir="$HOME/Music"; fi; ' +
            'if command -v xdg-open >/dev/null 2>&1; then xdg-open "$dir"; ' +
            'elif command -v gio >/dev/null 2>&1; then gio open "$dir"; ' +
            'elif command -v nemo >/dev/null 2>&1; then nemo "$dir"; ' +
            'elif command -v dolphin >/dev/null 2>&1; then dolphin "$dir"; ' +
            'elif command -v thunar >/dev/null 2>&1; then thunar "$dir"; ' +
            'elif command -v nautilus >/dev/null 2>&1; then nautilus "$dir"; ' +
            'elif command -v pcmanfm >/dev/null 2>&1; then pcmanfm "$dir"; fi',
            "bash", rawUrl
        ]);
    }

    function trashCurrentTrack() {
        var rawUrl = (musicBox.activePlayer && musicBox.activePlayer.metadata && musicBox.activePlayer.metadata["xesam:url"])
            ? musicBox.activePlayer.metadata["xesam:url"]
            : "";

        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--quiet",
            "bash", "-c",
            'url="$1"; target=""; ' +
            'if [ -n "$url" ] && [[ "$url" == file://* ]]; then ' +
            '    clean=$(python3 -c "import urllib.parse, sys; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "${url#file://}"); ' +
            '    if [ -f "$clean" ]; then target="$clean"; fi; ' +
            'fi; ' +
            'if [ -z "$target" ]; then ' +
            '    mpc_file=$(mpc current -f "%file%" 2>/dev/null); ' +
            '    if [ -n "$mpc_file" ]; then ' +
            '        mpd_dir=$(grep -E "^\\s*music_directory" ~/.config/mpd/mpd.conf 2>/dev/null | awk "{print \\$2}" | tr -d "\\\"\\\'"); ' +
            '        [ -z "$mpd_dir" ] && mpd_dir="$HOME/Music"; ' +
            '        eval mpd_dir_expanded="$mpd_dir"; ' +
            '        if [ -f "$mpd_dir_expanded/$mpc_file" ]; then target="$mpd_dir_expanded/$mpc_file"; ' +
            '        elif [ -f "$HOME/Music/$mpc_file" ]; then target="$HOME/Music/$mpc_file"; fi; ' +
            '    fi; ' +
            'fi; ' +
            'if [ -n "$target" ] && [ -f "$target" ]; then ' +
            '    fname=$(basename "$target"); ' +
            '    if command -v gio >/dev/null 2>&1; then gio trash "$target"; ' +
            '    elif command -v trash-put >/dev/null 2>&1; then trash-put "$target"; ' +
            '    else ' +
            '        tdir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"; mkdir -p "$tdir"; mv "$target" "$tdir/"; ' +
            '    fi; ' +
            '    notify-send -a Music -i user-trash "Moved to Trash" "$fname"; ' +
            'fi; ' +
            'pos=$(mpc current -f %position% 2>/dev/null); ' +
            'if [ -n "$pos" ] && [ "$pos" -gt 0 ] 2>/dev/null; then mpc del "$pos" 2>/dev/null || true; fi; ' +
            'mpc next 2>/dev/null || true',
            "bash", rawUrl
        ]);

if (musicBox.activePlayer && musicBox.activePlayer.canGoNext) {
musicBox.activePlayer.next();
}
}
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
musicBox.popupActive = !musicBox.popupActive;
if (!musicBox.popupActive) musicBox.confirmDeleteMode = false;
else if (musicBox.activePlayer) musicBox.activePlayer.positionChanged();
}
}
SlantedTooltip {
id: musicTooltip
moduleItem: musicBox
barWindow: musicBox.barWindow
tooltipActive: musicBox.popupActive
alignSide: "Left"
pin: musicBox.popupActive
slantLeft: musicBox.slantLeft
slantRight: musicBox.slantRight
tooltipHeight: musicBox.tooltipHeight
collapsedCoreWidth: musicBox.tooltipCollapsedWidth
expandedCoreWidth: musicBox.tooltipExpandedWidth
topOffset: musicBox.tooltipTopOffset
rightOffset: musicBox.tooltipRightOffset
Item {
id: containerWrapper
anchors.fill: parent
readonly property real slantRatio: musicTooltip.tooltipSlantWidth / musicTooltip.tooltipHeight
// 1. TRACK DETAILS
Item {
id: trackCard
y: 28
x: musicTooltip.slantX(y) + 36
width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
height: 95
SlantedBox {
anchors.fill: parent
slantLeft: musicTooltip.slantLeft
slantRight: musicTooltip.slantRight
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
font.family: themeFontFamily; font.pixelSize: 17; font.bold: true; color: themeBase05
horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
}
Text {
width: parent.width
text: musicBox.tooltipArtist
font.family: themeFontFamily; font.pixelSize: 14; color: themeBase05; opacity: 0.8
horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
}
Text {
width: parent.width
visible: musicBox.tooltipAlbum !== ""
text: musicBox.tooltipAlbum
font.family: themeFontFamily; font.pixelSize: 12; color: themeBase05; opacity: 0.6
horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
}
}
}
// 2. SEEK SLIDER
Row {
y: 135
x: musicTooltip.slantX(y) + 24
width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
spacing: 8
Text { text: musicBox.formatTime(musicBox.elapsedSeconds); font.family: themeFontFamily; font.pixelSize: 12; color: themeBase05; anchors.verticalCenter: parent.verticalCenter }
Slider {
id: seekSlider
width: parent.width - 90
anchors.verticalCenter: parent.verticalCenter
enabled: musicBox.playerAvailable && musicBox.activePlayer.canSeek && musicBox.activePlayer.positionSupported
from: 0; to: musicBox.totalSeconds > 0 ? musicBox.totalSeconds : 100
value: musicBox.elapsedSeconds
background: SlantedBox {
implicitHeight: 8; slantLeft: musicTooltip.slantLeft; slantRight: musicTooltip.slantRight; slantWidth: 10
color: themeBase03; borderColor: "transparent"
SlantedBox {
height: parent.height
width: Math.max(0, seekSlider.visualPosition * parent.width)
slantLeft: musicTooltip.slantLeft; slantRight: musicTooltip.slantRight; slantWidth: 10
color: themeBase05; borderColor: "transparent"
}
}
handle: SlantedBox {
width: 14; height: 14
x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
slantLeft: musicTooltip.slantLeft; slantRight: musicTooltip.slantRight; slantWidth: 6
color: themeBase05; borderColor: themeBase05
}
onMoved: if (musicBox.activePlayer && musicBox.activePlayer.canSeek) musicBox.activePlayer.position = value
}
Text { text: musicBox.formatTime(musicBox.totalSeconds); font.family: themeFontFamily; font.pixelSize: 12; color: themeBase05; anchors.verticalCenter: parent.verticalCenter }
}
// 3. VOLUME SLIDER
Row {
y: 180
x: musicTooltip.slantX(y) + 24
width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
spacing: 8
Text { text: "VOL"; font.family: themeFontFamily; font.pixelSize: 12; font.bold: true; color: themeBase05; anchors.verticalCenter: parent.verticalCenter }
Slider {
id: volSlider
width: parent.width - 80
anchors.verticalCenter: parent.verticalCenter
enabled: musicBox.playerAvailable && musicBox.activePlayer.volumeSupported
from: 0; to: 100
value: musicBox.currentVolume
onMoved: if (musicBox.activePlayer && musicBox.activePlayer.volumeSupported) musicBox.activePlayer.volume = value / 100.0
background: SlantedBox {
implicitHeight: 8; slantLeft: musicTooltip.slantLeft; slantRight: musicTooltip.slantRight; slantWidth: 10
color: themeBase03; borderColor: "transparent"
SlantedBox {
height: parent.height
width: Math.max(0, volSlider.visualPosition * parent.width)
slantLeft: musicTooltip.slantLeft; slantRight: musicTooltip.slantRight; slantWidth: 10
color: themeBase05; borderColor: "transparent"
}
}
handle: SlantedBox {
width: 14; height: 14
x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
slantLeft: musicTooltip.slantLeft; slantRight: musicTooltip.slantRight; slantWidth: 6
color: themeBase05; borderColor: themeBase05
}
}
Text { text: Math.round(volSlider.value) + "%"; font.family: themeFontFamily; font.pixelSize: 12; color: themeBase05; anchors.verticalCenter: parent.verticalCenter }
}
// 4. PLAYBACK CONTROLS
Row {
y: 230
x: musicTooltip.slantX(y) + 24
width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
spacing: 12
Item { width: Math.max(0, (parent.width - 324) / 2); height: 40 }
Rectangle {
width: 96; height: 34; radius: 6
color: themeBase00; border.color: themeBase05; border.width: 1.5
Text { anchors.centerIn: parent; text: "⏮ Prev"; font.bold: true; font.pixelSize: 13; color: themeBase05; opacity: musicBox.playerAvailable && musicBox.activePlayer.canGoPrevious ? 1.0 : 0.4 }
MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (musicBox.activePlayer && musicBox.activePlayer.canGoPrevious) musicBox.activePlayer.previous() }
}
Rectangle {
width: 106; height: 34; radius: 6
color: musicBox.playbackState === "play" ? themeBase05 : themeBase00
border.color: themeBase05; border.width: 1.5
Text { anchors.centerIn: parent; text: musicBox.playbackState === "play" ? "⏸ Pause" : "⏯ Play"; font.bold: true; font.pixelSize: 13; color: musicBox.playbackState === "play" ? themeBase00 : themeBase05 }
MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (musicBox.activePlayer && musicBox.activePlayer.canTogglePlaying) musicBox.activePlayer.togglePlaying() }
}
Rectangle {
width: 96; height: 34; radius: 6
color: themeBase00; border.color: themeBase05; border.width: 1.5
Text { anchors.centerIn: parent; text: "⏭ Next"; font.bold: true; font.pixelSize: 13; color: themeBase05; opacity: musicBox.playerAvailable && musicBox.activePlayer.canGoNext ? 1.0 : 0.4 }
MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (musicBox.activePlayer && musicBox.activePlayer.canGoNext) musicBox.activePlayer.next() }
}
}
// 5. UTILITY BUTTONS
Row {
y: 285
x: musicTooltip.slantX(y) + 24
width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
spacing: 12
Item {
width: {
var totalBtnW = musicBox.confirmDeleteMode ? 240 : 180;
return Math.max(0, (parent.width - totalBtnW) / 2);
}
height: 36
}
Rectangle {
width: 90; height: 32; radius: 6
visible: !musicBox.confirmDeleteMode
color: themeBase00; border.color: themeBase05; border.width: 1.5
Row {
anchors.centerIn: parent; spacing: 5
Text { text: "📂"; font.pixelSize: 13 }
Text { text: "Folder"; font.bold: true; font.pixelSize: 11; color: themeBase05 }
}
MouseArea {
anchors.fill: parent; cursorShape: Qt.PointingHandCursor
onClicked: { musicBox.openMusicDirectory(); musicBox.popupActive = false; }
}
}
Rectangle {
width: musicBox.confirmDeleteMode ? 130 : 84; height: 32; radius: 6
color: musicBox.confirmDeleteMode ? "#ff5555" : themeBase00
border.color: musicBox.confirmDeleteMode ? "#ff5555" : themeBase05
border.width: 1.5
Row {
anchors.centerIn: parent; spacing: 5
Text { text: "🗑️"; font.pixelSize: 13 }
Text { text: musicBox.confirmDeleteMode ? "Confirm?" : "Trash"; font.bold: true; font.pixelSize: 11; color: musicBox.confirmDeleteMode ? "#000" : themeBase05 }
}
MouseArea {
anchors.fill: parent; cursorShape: Qt.PointingHandCursor
onClicked: {
if (!musicBox.confirmDeleteMode) musicBox.confirmDeleteMode = true;
else { musicBox.trashCurrentTrack(); musicBox.confirmDeleteMode = false; }
}
}
}
Rectangle {
width: 70; height: 32; radius: 6; visible: musicBox.confirmDeleteMode
color: themeBase00; border.color: themeBase05; border.width: 1.5
Text { anchors.centerIn: parent; text: "Cancel"; font.bold: true; font.pixelSize: 11; color: themeBase05 }
MouseArea {
anchors.fill: parent; cursorShape: Qt.PointingHandCursor
onClicked: { musicBox.popupActive = false; musicBox.confirmDeleteMode = false; }
}
}
}
// 6. MPRIS WATCH SOURCE TOGGLES
RowLayout {
y: 335
x: musicTooltip.slantX(y) + 24
width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
spacing: 8
Text {
text: "Sources:"
font.family: themeFontFamily; font.pixelSize: 11; font.bold: true
color: themeBase05
}
Rectangle {
readonly property bool active: (shell && shell.settingsManager) ? shell.settingsManager.mprisWatchLocal : true
width: localTxt.implicitWidth + 14; height: 24; radius: 4
color: active ? themeBase05 : "#222"
border.color: themeBase05; border.width: 1
Text { id: localTxt; anchors.centerIn: parent; text: "🖥️ Local"; font.pixelSize: 10; font.bold: true; color: parent.active ? "#000" : themeBase05 }
MouseArea {
anchors.fill: parent; cursorShape: Qt.PointingHandCursor
onClicked: if (shell && shell.settingsManager) shell.settingsManager.mprisWatchLocal = !shell.settingsManager.mprisWatchLocal
}
}
Rectangle {
readonly property bool active: (shell && shell.settingsManager) ? shell.settingsManager.mprisWatchSpotify : true
width: spotTxt.implicitWidth + 14; height: 24; radius: 4
color: active ? "#1db954" : "#222"
border.color: "#1db954"; border.width: 1
Text { id: spotTxt; anchors.centerIn: parent; text: "🟢 Spotify"; font.pixelSize: 10; font.bold: true; color: parent.active ? "#000" : "#1db954" }
MouseArea {
anchors.fill: parent; cursorShape: Qt.PointingHandCursor
onClicked: if (shell && shell.settingsManager) shell.settingsManager.mprisWatchSpotify = !shell.settingsManager.mprisWatchSpotify
}
}
Rectangle {
readonly property bool active: (shell && shell.settingsManager) ? shell.settingsManager.mprisWatchBrowser : true
width: browTxt.implicitWidth + 14; height: 24; radius: 4
color: active ? themeBase0C : "#222"
border.color: themeBase0C; border.width: 1
Text { id: browTxt; anchors.centerIn: parent; text: "🌐 Browser"; font.pixelSize: 10; font.bold: true; color: parent.active ? "#000" : themeBase0C }
MouseArea {
anchors.fill: parent; cursorShape: Qt.PointingHandCursor
onClicked: if (shell && shell.settingsManager) shell.settingsManager.mprisWatchBrowser = !shell.settingsManager.mprisWatchBrowser
}
}
}
}
}
}
