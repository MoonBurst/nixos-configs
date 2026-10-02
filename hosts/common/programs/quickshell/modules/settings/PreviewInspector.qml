import QtQuick

// Nullified: All preview sliders are unified in OverlayInspectorWindow.qml.
// Dummy properties and signals prevent compilation errors in any window references.
Item {
    id: dummyInspector
    visible: false
    width: 0
    height: 0

    property string windowId: ""
    property var settingsManager: null
    property var theme: null
    property int defaultW: 840
    property int defaultH: 600
    property int defaultFH: 52
    property int defaultIS: 38
    property bool hasField: false
    property bool hasIcon: false
    property string defaultPolicy: "lazy"

    signal doneRequested()
}
