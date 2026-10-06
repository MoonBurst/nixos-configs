import QtQuick
import QtQuick.Layouts 1.15
import "../../../style" as Style

Item {
    id: previewComp

    property color previewBgColor: (typeof theme !== 'undefined' && theme.base00) ? theme.base00 : "#121212"
    property color headerSectionBg: (typeof theme !== 'undefined' && theme.base00) ? theme.base00 : "#121212"
    property color titleColor: (typeof theme !== 'undefined' && theme.base05) ? theme.base05 : "#f7f700"
    property color bodyTextColor: (typeof theme !== 'undefined' && theme.base06) ? theme.base06 : "#ebdbb2"
    property color scrollTrackBg: (typeof theme !== 'undefined' && theme.base01) ? theme.base01 : "#0f0f0f"
    property color scrollHandleColor: (typeof theme !== 'undefined' && theme.scrollHandleColor) ? theme.scrollHandleColor : "#003399"
    property int viewPadding: (typeof theme !== 'undefined' && theme.globalPadding) ? theme.globalPadding : 16
    property int titleSize: (typeof theme !== 'undefined' && theme.globalFontSize) ? theme.globalFontSize : 20
    property int metaSize: (typeof theme !== 'undefined' && theme.globalFontSize) ? theme.globalFontSize : 15
    property int bodySize: (typeof theme !== 'undefined' && theme.globalFontSize) ? theme.globalFontSize : 16
    property string previewFontFamily: (typeof theme !== 'undefined' && theme.fontFamily) ? theme.fontFamily : "Fira Sans"

    property color outerBorderColor: (typeof theme !== 'undefined' && theme.outerBorderColor) ? theme.outerBorderColor : "#003399"
    property color innerCardActiveBorder: (typeof theme !== 'undefined' && theme.innerBorderColor) ? theme.innerBorderColor : "#fabd2f"
    property int controlBorderWidth: (typeof theme !== 'undefined' && theme && theme.controlBorderWidth !== undefined) ? theme.controlBorderWidth : 2

    property var activeMailObject: null
    property string activeMailBodyText: ""

    // Broad detection: checks flags, parts, and inline body attachment tags
    readonly property bool hasAttachments: {
        if (!activeMailObject) return false;
        if (activeMailObject["has-attachment"] || activeMailObject.has_attachment || activeMailObject.has_attachments) return true;
        if (activeMailObject.attachments && activeMailObject.attachments.length > 0) return true;
        if (activeMailObject.parts && activeMailObject.parts.length > 0) return true;
        if (activeMailBodyText && (activeMailBodyText.indexOf("<#part") !== -1 || activeMailBodyText.indexOf("filename=") !== -1)) return true;
        return false;
    }

    property string unsubscribeUrl: findUnsubscribeUrl(activeMailBodyText)

    signal contactRequested(string email)
    signal downloadAttachmentsRequested(string msgId, string folderLabel)
    signal markSpamRequested(string msgId, string folderLabel)
    signal restoreSpamRequested(string msgId, string folderLabel)

    function findUnsubscribeUrl(rawText) {
        if (!rawText) return "";
        var urlRegex = /(https?:\/\/[^\s"'<>\(\)]*unsubscribe[^\s"'<>\(\)]*|https?:\/\/[^\s"'<>\(\)]*opt-?out[^\s"'<>\(\)]*)/gi;
        var match = rawText.match(urlRegex);
        return match ? match[0] : "";
    }

    function extractAttachmentNames(rawText) {
        if (!rawText) return [];
        var names = [];
        var regex = /filename=["']?([^"'\r\n>]+)["']?/gi;
        var match;
        while ((match = regex.exec(rawText)) !== null) {
            var full = match[1].trim();
            var shortName = full.split("/").pop();
            if (shortName.length > 0 && !names.includes(shortName)) {
                names.push(shortName);
            }
        }
        return names;
    }

    readonly property var detectedAttachmentNames: extractAttachmentNames(activeMailBodyText)

    function formatBody(rawText) {
        if (!rawText) return "";

        var cleaned = rawText
        .replace(/<#part[^>]*>/gi, "")
        .replace(/<#\/part>/gi, "");

        var escaped = cleaned
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");

        var formatted = escaped
        .replace(/\[b\](.*?)\[\/b\]/gi, "<b>$1</b>")
        .replace(/\[i\](.*?)\[\/i\]/gi, "<i>$1</i>")
        .replace(/\[u\](.*?)\[\/u\]/gi, "<u>$1</u>")
        .replace(/\[url=(.*?)\](.*?)\[\/url\]/gi, '<a href="$1">$2</a>')
        .replace(/\[url\](.*?)\[\/url\]/gi, '<a href="$1">$1</a>')
        .replace(/\[img\](.*?)\[\/img\]/gi, '<img src="$1" />');

        var urlRegex = /(<a [^>]+>.*?<\/a>)|(https?:\/\/[^\s<]+)/g;
        formatted = formatted.replace(urlRegex, function(m, g1, g2) {
            if (g1) return g1;
                                      return '<a href="' + g2 + '">' + g2 + '</a>';
        });

        formatted = formatted.replace(/\r\n/g, "<br>").replace(/\n/g, "<br>");
        return formatted;
    }

    // Header card with safe insets clearing the top-left hexagon chamfer
    Item {
        id: headerRect
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: previewComp.viewPadding
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        implicitHeight: headerContentCol.implicitHeight + 28
        height: implicitHeight
        visible: activeMailObject !== null

        Style.ShapeBox {
            id: headerBg
            anchors.fill: parent
            role: "input"
            slantWidth: 12
            color: previewComp.headerSectionBg
            borderColor: previewComp.innerCardActiveBorder
            borderWidth: previewComp.controlBorderWidth
        }

        ColumnLayout {
            id: headerContentCol
            anchors.fill: parent
            // Safe insets to prevent the top-left chamfer from cutting through the title
            anchors.leftMargin: Math.max(38, headerBg.leftPadding)
            anchors.rightMargin: Math.max(38, headerBg.rightPadding)
            anchors.topMargin: Math.max(14, headerBg.topPadding)
            anchors.bottomMargin: Math.max(14, headerBg.bottomPadding)
            spacing: 8

            Text {
                text: activeMailObject ? activeMailObject.subject : "No Subject Selected"
                font.family: previewComp.previewFontFamily
                font.pixelSize: previewComp.titleSize
                font.bold: true
                color: previewComp.titleColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: activeMailObject ? "From: " + (activeMailObject.from ? (activeMailObject.from.name || activeMailObject.from.addr) : "Unknown") : ""
                font.family: previewComp.previewFontFamily
                font.pixelSize: previewComp.metaSize
                color: previewComp.bodyTextColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // Contact / Spam / Unsubscribe Action chips
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    width: 110; height: 28

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 6
                        color: conHov.hovered ? previewComp.scrollHandleColor : previewComp.scrollTrackBg
                        borderColor: previewComp.scrollHandleColor
                        borderWidth: 1.5
                    }

                    Text {
                        text: "👤 + Contact"
                        font.family: previewComp.previewFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: conHov.hovered ? "#fff" : previewComp.bodyTextColor
                        anchors.centerIn: parent
                    }

                    HoverHandler { id: conHov }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var emailAddr = activeMailObject && activeMailObject.from ? (activeMailObject.from.addr || activeMailObject.from.name || "") : "";
                            previewComp.contactRequested(emailAddr);
                        }
                    }
                }

                Item {
                    width: 100; height: 28
                    visible: previewComp.activeMailObject ? previewComp.activeMailObject.folder.toLowerCase() !== "spam" : false

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 6
                        color: "#d79921"
                        borderColor: "#fabd2f"
                        borderWidth: 1.5
                    }

                    Text { text: "⚠️ Spam"; font.family: previewComp.previewFontFamily; font.pixelSize: 11; font.bold: true; color: "#1d2021"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (activeMailObject) previewComp.markSpamRequested(activeMailObject.id.toString(), activeMailObject.folder)
                    }
                }

                Item {
                    width: 100; height: 28
                    visible: previewComp.activeMailObject ? previewComp.activeMailObject.folder.toLowerCase() === "spam" : false

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 6
                        color: "#b8bb26"
                        borderColor: "#b8bb26"
                        borderWidth: 1.5
                    }

                    Text { text: "✅ Not Spam"; font.family: previewComp.previewFontFamily; font.pixelSize: 11; font.bold: true; color: "#282828"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (activeMailObject) previewComp.restoreSpamRequested(activeMailObject.id.toString(), activeMailObject.folder)
                    }
                }

                Item {
                    width: 115; height: 28
                    visible: previewComp.unsubscribeUrl !== ""

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 6
                        color: "#cc241d"
                        borderColor: "#fb4934"
                        borderWidth: 1.5
                    }

                    Text { text: "🚫 Unsubscribe"; font.family: previewComp.previewFontFamily; font.pixelSize: 11; font.bold: true; color: "#fbf1c7"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (previewComp.unsubscribeUrl !== "") Qt.openUrlExternally(previewComp.unsubscribeUrl)
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    Flickable {
        id: bodyFlickableCanvas
        anchors.top: headerRect.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.bottomMargin: previewComp.viewPadding
        anchors.leftMargin: previewComp.viewPadding
        anchors.rightMargin: previewComp.viewPadding + 16
        contentWidth: width
        contentHeight: previewContentLayoutColumn.implicitHeight + 40
        clip: true
        visible: activeMailObject !== null

        ColumnLayout {
            id: previewContentLayoutColumn
            width: parent.width
            spacing: 16

            // Dedicated Attached Files Banner with the "Save Files" button integrated directly inside
            Item {
                Layout.fillWidth: true
                height: 44
                visible: previewComp.hasAttachments || previewComp.detectedAttachmentNames.length > 0

                Style.ShapeBox {
                    id: attachBoxBg
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 8
                    color: previewComp.scrollTrackBg
                    borderColor: (typeof theme !== 'undefined') ? theme.base0C : "#04f100"
                    borderWidth: 1.5
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(16, attachBoxBg.leftPadding)
                    anchors.rightMargin: Math.max(16, attachBoxBg.rightPadding)
                    spacing: 10

                    Text {
                        text: "📁 Attached:"
                        font.bold: true
                        font.pixelSize: 13
                        color: (typeof theme !== 'undefined') ? theme.base0C : "#04f100"
                    }

                    // Attachment file chips
                    Repeater {
                        model: previewComp.detectedAttachmentNames
                        Rectangle {
                            height: 26
                            width: fnText.implicitWidth + 16
                            radius: 4
                            color: "#181825"
                            border.color: "#45475a"
                            border.width: 1
                            Text {
                                id: fnText
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 11
                                color: previewComp.bodyTextColor
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Save / Download Attachments Button positioned inside the attachments banner
                    Item {
                        width: dlText.implicitWidth + 26
                        height: 28

                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            slantWidth: 6
                            color: dlHov.hovered ? ((typeof theme !== 'undefined') ? theme.base0C : "#04f100") : "#181825"
                            borderColor: (typeof theme !== 'undefined') ? theme.base0C : "#04f100"
                            borderWidth: 1.5
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "💾"; font.pixelSize: 11 }
                            Text {
                                id: dlText
                                text: "Save Files"
                                font.family: previewComp.previewFontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: dlHov.hovered ? "#000" : ((typeof theme !== 'undefined') ? theme.base0C : "#04f100")
                            }
                        }

                        HoverHandler { id: dlHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activeMailObject) {
                                    previewComp.downloadAttachmentsRequested(activeMailObject.id.toString(), activeMailObject.folder);
                                }
                            }
                        }
                    }
                }
            }

            Text {
                id: textBodyContent
                Layout.fillWidth: true
                text: previewComp.formatBody(previewComp.activeMailBodyText !== "" ? previewComp.activeMailBodyText : "Select an email...")
                textFormat: Text.StyledText
                font.family: previewComp.previewFontFamily
                font.pixelSize: previewComp.bodySize
                color: previewComp.bodyTextColor
                linkColor: previewComp.innerCardActiveBorder
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
        }
    }

    Rectangle {
        id: customVerticalScrollTrack
        width: 6; radius: 3; color: previewComp.scrollTrackBg
        anchors.right: parent.right; anchors.top: headerRect.bottom; anchors.bottom: parent.bottom
        anchors.topMargin: 12; anchors.bottomMargin: previewComp.viewPadding; anchors.rightMargin: 8
        visible: bodyFlickableCanvas.contentHeight > bodyFlickableCanvas.height

        Rectangle {
            id: customScrollHandleThumb
            width: parent.width; radius: parent.radius; color: previewComp.scrollHandleColor
            height: Math.max(30, (bodyFlickableCanvas.height / bodyFlickableCanvas.contentHeight) * parent.height)
            y: (bodyFlickableCanvas.contentY / (bodyFlickableCanvas.contentHeight - bodyFlickableCanvas.height)) * (parent.height - height)
        }
    }
}
