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
                text: {
                    if (root.valueFormatter) return root.valueFormatter(sliderControl.value);
                    if (root.stepSize < 1) return sliderControl.value.toFixed(1) + root.unit;
                    return Math.round(sliderControl.value) + root.unit;
                }
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

            // Do NOT use `value: root.value` — a user drag would destroy the
            // binding and sever all future external updates. A conditional
            // Binding suspended during drag is the correct two-way pattern.
            Binding {
                target: sliderControl
                property: "value"
                value: root.value
                when: !sliderControl.pressed
                restoreMode: Binding.RestoreBindingOrValue
            }

            onMoved: {
                // Do NOT write back to root.value here — that would sever the
                // caller's own binding (`value: settingsManager.foo`). Just
                // emit and let the caller decide.
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
                    width: Math.max(0, Math.min(parent.width, (sliderControl.visualPosition || 0) * parent.width))
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: 8
                    color: root.base05
                    borderColor: "transparent"
                }
            }

            handle: SlantedBox {
                width: 18
                height: 20
                x: Math.round(sliderControl.leftPadding + (sliderControl.visualPosition || 0) * (sliderControl.availableWidth - width))
                y: Math.round(sliderControl.topPadding + (sliderControl.availableHeight - height) / 2)
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
