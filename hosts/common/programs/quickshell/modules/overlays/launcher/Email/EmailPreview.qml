import QtQuick
import Quickshell

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes
    property var stylixTheme

    color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
    border.color: stylixTheme ? stylixTheme.base02 : "#444455"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
    radius: stylixTheme ? stylixTheme.defaultCardRadius : controller.defaultCardRadius

    function getMessageBodyText() {
        var txt = "";
        if (controller.messageBody && String(controller.messageBody).trim().length > 0) {
            txt = String(controller.messageBody);
        } else if (controller.currentMessageBody && String(controller.currentMessageBody).trim().length > 0) {
            txt = String(controller.currentMessageBody);
        } else if (processes.innerMessageBody && String(processes.innerMessageBody).trim().length > 0) {
            txt = String(processes.innerMessageBody);
        }

        var cleanTxt = txt.trim();
        if (cleanTxt === "Loading message...") return "⏳ Reading message file from local disk maildir store...";
        if (cleanTxt === "") return "📄 Select an email row item from the list to display its message contents here.";

        cleanTxt = cleanTxt.replace(/<#part[^>]*>/gi, "");
        cleanTxt = cleanTxt.replace(/<#\/part>/gi, "");

        return cleanTxt.trim();
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: stylixTheme ? stylixTheme.globalPadding : 16
        clip: true
        contentWidth: parent.width - (stylixTheme ? (stylixTheme.globalPadding * 2) : 32)
        contentHeight: previewTextDisplay.contentHeight + 40

        Text {
            id: previewTextDisplay
            // FIXED: Matches child width perfectly to the content container wrap boundary
            width: parent.width
            text: root.getMessageBodyText()
            wrapMode: Text.Wrap
            color: "white"

            font.family: "monospace"
            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 2) : 16
        }
    }
}
