import QtQuick

Rectangle {
    id: previewComp

    // ============================================================================
    // SAFE VARIABLE CHECKS AGAINST THE CENTRAL THEME OBJECT
    // ============================================================================
    property color previewBgColor: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color headerSectionBg: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color titleColor: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
    property color bodyTextColor: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"
    property color scrollTrackBg: (typeof theme !== 'undefined') ? theme.base01 : "#0f0f0f"
    property color scrollHandleColor: (typeof theme !== 'undefined') ? theme.base03 : "#003399"
    property int viewPadding: (typeof theme !== 'undefined') ? theme.globalPadding : 20
    property int titleSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property int metaSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property int bodySize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property string previewFontFamily: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"

    // Core Outer Large Container Border Configuration
    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 5

    // Inner Nested Small Element Border Configuration
    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5

    // Controller Wire Anchors
    property var activeMailObject: null
    property string activeMailBodyText: ""

    signal contactRequested(string email)

    color: previewBgColor
    border.color: outerBorderColor
    border.width: outerBorderThickness
    radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

    // FIXED: Regex helper that converts raw plain text URL blocks into standard clickable HTML links
    function formatBodyWithLinks(rawText) {
        if (!rawText) return "";
        var urlRegex = /(https?:\/\/[^\s]+)/g;
        return rawText.replace(urlRegex, '<a href="$1">$1</a>');
    }

    Column {
        anchors.fill: parent
        anchors.margins: previewComp.viewPadding
        spacing: 20
        visible: activeMailObject !== null

        Rectangle {
            width: parent.width
            height: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 20
            color: previewComp.headerSectionBg
            radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
            border.color: previewComp.innerCardActiveBorder
            border.width: previewComp.innerCardActiveThickness

            Column {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 5

                Text {
                    text: activeMailObject ? activeMailObject.subject : "No Subject Selected"
                    font.family: previewComp.previewFontFamily
                    font.pixelSize: previewComp.titleSize
                    font.bold: true
                    color: previewComp.titleColor
                    width: parent.width
                    elide: Text.ElideRight
                }

                Row {
                    spacing: 15
                    width: parent.width

                    Text {
                        text: activeMailObject ? "From: " + (activeMailObject.from ? (activeMailObject.from.name || activeMailObject.from.addr) : "Unknown") : ""
                        font.family: previewComp.previewFontFamily
                        font.pixelSize: previewComp.metaSize
                        color: previewComp.bodyTextColor
                        elide: Text.ElideRight
                        width: parent.width - 180
                    }

                    Rectangle {
                        width: 150
                        height: 26
                        color: previewComp.scrollTrackBg
                        radius: 4
                        border.color: previewComp.scrollHandleColor
                        border.width: 1
                        visible: activeMailObject !== null
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "👤 + Contacts"
                            font.family: previewComp.previewFontFamily
                            font.pixelSize: previewComp.metaSize - 4
                            font.bold: true
                            color: previewComp.bodyTextColor
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var emailAddr = "";
                                if (activeMailObject && activeMailObject.from) {
                                    emailAddr = activeMailObject.from.addr || activeMailObject.from.name || "";
                                }
                                previewComp.contactRequested(emailAddr);
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - 150

            Flickable {
                id: bodyFlickableCanvas
                anchors.fill: parent
                anchors.rightMargin: 16
                contentWidth: width
                contentHeight: textBodyContent.height
                clip: true

                Text {
                    id: textBodyContent
                    width: parent.width
                    // FIXED: Renders the compiled rich HTML block containing clickable anchor links
                    text: previewComp.formatBodyWithLinks(previewComp.activeMailBodyText !== "" ? previewComp.activeMailBodyText : "Select an email or wait for preview data strings to fetch...")
                    textFormat: Text.StyledText
                    font.family: previewComp.previewFontFamily
                    font.pixelSize: previewComp.bodySize
                    color: previewComp.bodyTextColor
                    linkColor: previewComp.innerCardActiveBorder // Stylize links in your beautiful theme accent
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere

                    // FIXED: Launches default desktop web browser when link is clicked
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link);
                    }
                }
            }

            Rectangle {
                id: customVerticalScrollTrack
                width: 6
                radius: 3
                color: previewComp.scrollTrackBg
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: bodyFlickableCanvas.contentHeight > bodyFlickableCanvas.height

                Rectangle {
                    id: customScrollHandleThumb
                    width: parent.width
                    radius: parent.radius
                    color: previewComp.scrollHandleColor

                    height: Math.max(30, (bodyFlickableCanvas.height / bodyFlickableCanvas.contentHeight) * parent.height)
                    y: (bodyFlickableCanvas.contentY / (bodyFlickableCanvas.contentHeight - bodyFlickableCanvas.height)) * (parent.height - height)
                }
            }
        }
    }
}
