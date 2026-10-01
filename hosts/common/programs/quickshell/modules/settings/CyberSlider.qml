// modules/settings/CyberSlider.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../style"

Item {
    id: root

    property string label: "Setting"
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property var theme: null
    property var valueFormatter: null

    signal valueModified(real newVal)

    onValueChanged: {
        if (!sliderControl.pressed) {
            sliderControl.value = root.value;
        }
    }

    Layout.fillWidth: true
    width: parent ? parent.width : 600
    implicitWidth: 600
    implicitHeight: Math.max(48, root.fontSize * 2.8)

    readonly property color base00: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color base02: (theme && theme.base02) ? theme.base02 : "#313244"
    readonly property color base03: (theme && theme.base03) ? theme.base03 : "#45475a"
    readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color base08: (theme && theme.base08) ? theme.base08 : "#f38ba8"
    readonly property string fontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
    property int fontSize: (theme && theme.overlayFontSize) ? theme.overlayFontSize : ((theme && theme.globalFontSize) ? theme.globalFontSize : 14)

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.bold: true
                color: root.base05
                Layout.fillWidth: true
            }

            Text {
                text: root.valueFormatter ? root.valueFormatter(sliderControl.value) : (Math.round(sliderControl.value) + root.unit)
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.bold: true
                color: root.base05
            }
        }

        Slider {
            id: sliderControl
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value

            onMoved: {
                root.value = value;
                root.valueModified(value);
            }

            background: SlantedBox {
                implicitHeight: 14
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 8
                color: root.base02
                borderColor: root.base03
                borderWidth: 1

                SlantedBox {
                    height: parent.height
                    width: Math.max(12, sliderControl.visualPosition * parent.width)
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: 8
                    color: root.base05
                    borderColor: "transparent"
                }
            }

            handle: SlantedBox {
                x: sliderControl.leftPadding + sliderControl.visualPosition * (sliderControl.availableWidth - width)
                y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
                implicitWidth: 18
                implicitHeight: 20
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 6
                color: sliderControl.pressed ? root.base08 : root.base05
                borderColor: root.base00
                borderWidth: 1
            }
        }
    }
}
