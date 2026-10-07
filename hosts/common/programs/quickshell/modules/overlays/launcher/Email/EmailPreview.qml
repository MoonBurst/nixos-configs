import QtQuick
import QtQuick.LocalStorage 2.0

Rectangle {
    id: previewComp

    // ============================================================================
    // THEME & STYLE SAFE PROPERTY FALLBACKS
    // ============================================================================
    property color previewBgColor: (typeof theme !== 'undefined' && theme.base00) ? theme.base00 : "#121212"
    property color headerSectionBg: (typeof theme !== 'undefined' && theme.base00) ? theme.base00 : "#121212"
    property color titleColor: (typeof theme !== 'undefined' && theme.base05) ? theme.base05 : "#f7f700"
    property color bodyTextColor: (typeof theme !== 'undefined' && theme.base06) ? theme.base06 : "#ebdbb2"
    property color scrollTrackBg: (typeof theme !== 'undefined' && theme.base01) ? theme.base01 : "#0f0f0f"
    property color scrollHandleColor: (typeof theme !== 'undefined' && theme.scrollHandleColor) ? theme.scrollHandleColor : "#003399"
    property int viewPadding: (typeof theme !== 'undefined' && theme.globalPadding) ? theme.globalPadding : 20
    property int titleSize: (typeof theme !== 'undefined' && theme.globalFontSize) ? theme.globalFontSize : 20
    property int metaSize: (typeof theme !== 'undefined' && theme.globalFontSize) ? theme.globalFontSize : 20
    property int bodySize: (typeof theme !== 'undefined' && theme.globalFontSize) ? theme.globalFontSize : 20
    property string previewFontFamily: (typeof theme !== 'undefined' && theme.fontFamily) ? theme.fontFamily : "Fira Sans"

    property color outerBorderColor: (typeof theme !== 'undefined' && theme.outerBorderColor) ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 5
    property color innerCardActiveBorder: (typeof theme !== 'undefined' && theme.innerBorderColor) ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5

    // Controller Bindings
    property var activeMailObject: null
    property string activeMailBodyText: ""
    property bool hasAttachments: activeMailObject ? !!(activeMailObject["has-attachment"] || activeMailObject.has_attachment || (activeMailObject.attachments && activeMailObject.attachments.length > 0)) : false

    // Automated Unsubscribe URL Scanner
    property string unsubscribeUrl: findUnsubscribeUrl(activeMailBodyText)

    signal contactRequested(string email)
    signal downloadAttachmentsRequested(string msgId, string folderLabel)
    signal markSpamRequested(string msgId, string folderLabel)
    signal restoreSpamRequested(string msgId, string folderLabel) // <-- Added Not Spam Signal

    color: previewBgColor
    border.color: outerBorderColor
    border.width: outerBorderThickness
    radius: (typeof theme !== 'undefined' && theme.defaultCardRadius) ? theme.defaultCardRadius : 10

    // Scans plain text or raw HTML inside the email body for unsubscribe link structures
    function findUnsubscribeUrl(rawText) {
        if (!rawText) return "";
        var urlRegex = /(https?:\/\/[^\s"'<>\(\)]*unsubscribe[^\s"'<>\(\)]*|https?:\/\/[^\s"'<>\(\)]*opt-?out[^\s"'<>\(\)]*)/gi;
        var match = rawText.match(urlRegex);
        return match ? match[0] : "";
    }

    // Consolidated BBCode, HTML Sanitizer, & Plain-Text Link compiler
    function formatBody(rawText) {
        if (!rawText) return "";

        var escaped = rawText
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
        formatted = formatted.replace(urlRegex, function(match, group1, group2) {
            if (group1) {
                return group1;
            } else {
                return '<a href="' + group2 + '">' + group2 + '</a>';
            }
        });

        formatted = formatted.replace(/\r\n/g, "<br>").replace(/\n/g, "<br>");
        return formatted;
    }

    // ============================================================================
    // HEADER METADATA SECTION
    // ============================================================================
    Rectangle {
        id: headerRect
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: previewComp.viewPadding
        height: 100; color: previewComp.headerSectionBg; visible: activeMailObject !== null
        radius: (typeof theme !== 'undefined' && theme.defaultCardRadius) ? theme.defaultCardRadius : 10
        border.color: previewComp.innerCardActiveBorder; border.width: previewComp.innerCardActiveThickness

        Column {
            anchors.fill: parent; anchors.margins: 15; spacing: 5

            Text {
                text: activeMailObject ? activeMailObject.subject : "No Subject Selected"
                font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.titleSize; font.bold: true
                color: previewComp.titleColor; width: parent.width; elide: Text.ElideRight
            }

            Row {
                spacing: 15; width: parent.width

                Text {
                    text: activeMailObject ? "From: " + (activeMailObject.from ? (activeMailObject.from.name || activeMailObject.from.addr) : "Unknown") : ""
                    font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize; color: previewComp.bodyTextColor
                    elide: Text.ElideRight
                    // Dynamically subtracts visible button widths (including standard 125px Spam/Not Spam space)
                    width: parent.width - (previewComp.hasAttachments ? 155 : 0) - (previewComp.unsubscribeUrl !== "" ? 135 : 0) - (previewComp.activeMailObject ? 125 : 0) - 145
                }

                Rectangle {
                    width: 140; height: 26; color: previewComp.scrollTrackBg; radius: 4; border.color: "#458588"; border.width: 1
                    visible: previewComp.hasAttachments; anchors.verticalCenter: parent.verticalCenter

                    Text { text: "📎 Save Attachments"; font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize - 4; font.bold: true; color: previewComp.bodyTextColor; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (activeMailObject) previewComp.downloadAttachmentsRequested(activeMailObject.id.toString(), activeMailObject.folder)
                    }
                }

                // Interactive Unsubscribe Shortcut Link
                Rectangle {
                    width: 120; height: 26; color: "#cc241d"; radius: 4; border.color: "#fb4934"; border.width: 1
                    visible: previewComp.unsubscribeUrl !== ""; anchors.verticalCenter: parent.verticalCenter

                    Text { text: "🚫 Unsubscribe"; font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize - 4; font.bold: true; color: "#fbf1c7"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (previewComp.unsubscribeUrl !== "") {
                                Qt.openUrlExternally(previewComp.unsubscribeUrl)
                            }
                        }
                    }
                }

                // Report Spam Button (Hidden if we are already inside the Spam folder)
                Rectangle {
                    width: 110; height: 26; color: "#d79921"; radius: 4; border.color: "#fabd2f"; border.width: 1
                    visible: previewComp.activeMailObject ? previewComp.activeMailObject.folder.toLowerCase() !== "spam" : false
                    anchors.verticalCenter: parent.verticalCenter

                    Text { text: "⚠️ Mark Spam"; font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize - 4; font.bold: true; color: "#1d2021"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (activeMailObject) {
                                previewComp.markSpamRequested(activeMailObject.id.toString(), activeMailObject.folder);
                            }
                        }
                    }
                }

                // Not Spam Recovery Button (Visible ONLY inside the Spam folder)
                Rectangle {
                    width: 110; height: 26; color: "#b8bb26"; radius: 4; border.color: "#b8bb26"; border.width: 1
                    visible: previewComp.activeMailObject ? previewComp.activeMailObject.folder.toLowerCase() === "spam" : false
                    anchors.verticalCenter: parent.verticalCenter

                    Text { text: "✅ Not Spam"; font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize - 4; font.bold: true; color: "#282828"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (activeMailObject) {
                                previewComp.restoreSpamRequested(activeMailObject.id.toString(), activeMailObject.folder);
                            }
                        }
                    }
                }

                Rectangle {
                    width: 130; height: 26; color: previewComp.scrollTrackBg; radius: 4; border.color: previewComp.scrollHandleColor; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text { text: "👤 + Contacts"; font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize - 4; font.bold: true; color: previewComp.bodyTextColor; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var emailAddr = activeMailObject && activeMailObject.from ? (activeMailObject.from.addr || activeMailObject.from.name || "") : "";
                            previewComp.contactRequested(emailAddr);
                        }
                    }
                }
            }
        }
    }

    // ============================================================================
    // SCROLLABLE BODY VIEWPORT SECTION
    // ============================================================================
    Flickable {
        id: bodyFlickableCanvas
        anchors.top: headerRect.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 15; anchors.bottomMargin: previewComp.viewPadding; anchors.leftMargin: previewComp.viewPadding; anchors.rightMargin: previewComp.viewPadding + 16
        contentWidth: width; contentHeight: previewContentLayoutColumn.height; clip: true; visible: activeMailObject !== null

        Column {
            id: previewContentLayoutColumn; width: parent.width; spacing: 20

            Text {
                id: textBodyContent; width: parent.width
                text: previewComp.formatBody(previewComp.activeMailBodyText !== "" ? previewComp.activeMailBodyText : "Select an email...")
                textFormat: Text.StyledText; font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.bodySize; color: previewComp.bodyTextColor
                linkColor: previewComp.innerCardActiveBorder; wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }

            // Inline Attachment Previews
            Column {
                id: attachmentPreviewsSection; width: parent.width; spacing: 15; visible: previewComp.hasAttachments

                Repeater {
                    model: activeMailObject && activeMailObject.attachments ? activeMailObject.attachments : []
                    delegate: Column {
                        width: parent.width; spacing: 8

                        property bool isImage: {
                            if (!modelData) return false;
                            var mime = (modelData.mime || "").toLowerCase();
                            var fname = (modelData.filename || "").toLowerCase();
                            return (mime.indexOf("image/") === 0) ||
                            fname.endsWith(".png") || fname.endsWith(".jpg") ||
                            fname.endsWith(".jpeg") || fname.endsWith(".gif") ||
                            fname.endsWith(".bmp") || fname.endsWith(".webp");
                        }

                        property bool isText: modelData.filename ? (modelData.filename.endsWith(".txt") || modelData.filename.endsWith(".log") || modelData.filename.endsWith(".sh") || modelData.filename.endsWith(".ini") || modelData.filename.endsWith(".zshrc") || modelData.filename.endsWith(".conf")) : false

                        Rectangle {
                            width: parent.width; height: 32; color: previewComp.scrollTrackBg; radius: 4; border.color: "#3c3836"; border.width: 1
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 10; spacing: 8
                                Text { text: "📎"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: modelData.filename + " (" + (modelData.mime || "unknown") + ")"
                                    font.family: previewComp.previewFontFamily; font.pixelSize: previewComp.metaSize - 4; color: previewComp.bodyTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Image {
                            visible: isImage && modelData.local_path && modelData.local_path !== ""
                            source: visible ? "file://" + modelData.local_path : ""
                            width: Math.min(parent.width, 320); height: width * 0.625; fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Rectangle {
                            visible: isText && modelData.local_path && modelData.local_path !== ""
                            width: parent.width; height: 180; color: "#0f0f0f"; radius: 4; border.color: "#3c3836"; border.width: 1

                            Flickable {
                                anchors.fill: parent; anchors.margins: 10; contentWidth: width; contentHeight: previewText.height; clip: true
                                Text { id: previewText; width: parent.width; wrapMode: Text.Wrap; font.family: "Fira Code"; font.pixelSize: previewComp.bodySize - 4; color: "#bdae93" }
                            }

                            Component.onCompleted: {
                                if (visible && modelData.local_path) {
                                    var xhr = new XMLHttpRequest();
                                    xhr.open("GET", "file://" + modelData.local_path, true);
                                    xhr.onreadystatechange = function() {
                                        if (xhr.readyState === XMLHttpRequest.DONE) {
                                            previewText.text = xhr.responseText;
                                            xhr = null;
                                        }
                                    }
                                    xhr.send();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Scrollbar Track
    Rectangle {
        id: customVerticalScrollTrack; width: 6; radius: 3; color: previewComp.scrollTrackBg; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.topMargin: headerRect.height + previewComp.viewPadding + 20; anchors.bottomMargin: previewComp.viewPadding; anchors.rightMargin: 8
        visible: bodyFlickableCanvas.contentHeight > bodyFlickableCanvas.height

        Rectangle {
            id: customScrollHandleThumb; width: parent.width; radius: parent.radius; color: previewComp.scrollHandleColor
            height: Math.max(30, (bodyFlickableCanvas.height / bodyFlickableCanvas.contentHeight) * parent.height)
            y: (bodyFlickableCanvas.contentY / (bodyFlickableCanvas.contentHeight - bodyFlickableCanvas.height)) * (parent.height - height)
        }
    }
}
