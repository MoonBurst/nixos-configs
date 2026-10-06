import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: emailWindow

    windowId: "email"
    defaultW: 1500
        defaultH: 900
            defaultPolicy: "lazy"

                property bool isFileDialogActive: false

                // 1. Keep window open while composing or picking files so you can drag-and-drop
                // or interact with external file managers without the email overlay closing
                readonly property bool effectiveDismissOnBlur: !emailEngine.isComposing && !emailWindow.isFileDialogActive && (settingsManager ? settingsManager.getWindowDismissOnBlur(windowId, true) : true)

                // 2. Prevent window from closing on Escape while composing so ComposeModal handles it
                readonly property bool effectiveEscapeCloses: !emailEngine.isComposing && !emailWindow.isFileDialogActive && (settingsManager ? settingsManager.getWindowEscapeCloses(windowId, true) : true)

                // 3. Drop layer and release exclusive keyboard focus while FileDialog is active
                // so the system file picker spawns in the foreground with full input focus
                WlrLayershell.layer: isFileDialogActive ? WlrLayer.Bottom : (isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay)
                WlrLayershell.keyboardFocus: (visible && !isPreviewMode && !isFileDialogActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                Backend.EmailEngine { id: emailEngine }

                QtObject {
                    id: dynamicEmailTheme
                    readonly property var src: emailWindow.theme

                    readonly property color base00: src ? src.base00 : "#121212"
                    readonly property color base01: src ? src.base01 : "#181825"
                    readonly property color base02: src ? src.base02 : "#313244"
                    readonly property color base03: src ? src.base03 : "#003399"
                    readonly property color base04: src ? src.base04 : "#45475a"
                    readonly property color base05: src ? src.base05 : "yellow"
                    readonly property color base06: src ? src.base06 : "white"
                    readonly property color base07: src ? src.base07 : "#cccccc"
                    readonly property color base08: src ? src.base08 : "#ff5555"
                    readonly property color base09: src ? src.base09 : "#fe8019"
                    readonly property color base0A: src ? src.base0A : "#fabd2f"
                    readonly property color base0B: src ? src.base0B : "#545454"
                    readonly property color base0C: src ? src.base0C : "#04f100"
                    readonly property color base0D: src ? src.base0D : "#003399"
                    readonly property color base0E: src ? src.base0E : "#675ddb"
                    readonly property color base0F: src ? src.base0F : "#ff8019"

                    readonly property string fontFamily: src ? src.fontFamily : "monospace"
                    readonly property int defaultCardWidth: (src && src.defaultCardWidth) ? src.defaultCardWidth : 420
                    readonly property int defaultCardHeight: (src && src.defaultCardHeight) ? src.defaultCardHeight : 140
                    readonly property int defaultCardRadius: (src && src.defaultCardRadius) ? src.defaultCardRadius : 10
                    readonly property int globalBorderWidth: (src && src.globalBorderWidth) ? src.globalBorderWidth : 3
                    readonly property int globalPadding: (src && src.globalPadding) ? src.globalPadding : 16
                    readonly property int globalFontSize: (src && src.globalFontSize) ? src.globalFontSize : 14
                    readonly property int controlBorderWidth: (src && src.controlBorderWidth) ? src.controlBorderWidth : 2
                    readonly property color scrollHandleColor: (src && src.scrollHandleColor) ? src.scrollHandleColor : "#003399"

                    readonly property color innerBorderColor: (src && src.base05) ? src.base05 : "yellow"
                    readonly property color outerBorderColor: emailWindow.isCardActive ? emailWindow.activeBorderColor : emailWindow.inactiveBorderColor
                }

                onPreShow: {
                    emailEngine.checkHimalaya();
                    emailEngine.readMailCache();
                    emailEngine.syncMail();
                }

                viewComponent: Component {
                    Frontend.EmailView {
                        engine: emailEngine
                        theme: dynamicEmailTheme
                        settingsManager: emailWindow.settingsManager
                        onCloseRequested: emailWindow.close()
                    }
                }
}
