import QtQuick

Rectangle {
    id: listComp

    property color listBgColor: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color itemSelectedBg: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color itemBorderColor: (typeof theme !== 'undefined') ? theme.base01 : "#0f0f0f"
    property color senderTextColor: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
    property color subjectTextColor: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"
    property int listPadding: (typeof theme !== 'undefined') ? theme.globalPadding : 20
    property int itemHeight: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 50
    property int textMainSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property int textSubSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property string listFontFamily: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"

    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 3

    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5

    property var mailItems: []
    property int activeMailIndex: 0

    // Search Engine Configuration Bindings
    property bool searchVisible: false
    property string searchQuery: ""
    property bool searchCaseSensitive: false

    signal starToggled(int index)
    signal readToggled(int index)

    color: listBgColor
    border.color: outerBorderColor
    border.width: outerBorderThickness
    radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

    function toggleSearch() {
        searchVisible = !searchVisible;
        if (searchVisible) {
            searchInput.forceActiveFocus();
        } else {
            searchInput.text = "";
            rootWindow.forceActiveFocus();
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: listComp.listPadding
        spacing: 12

        // ============================================================================
        // SEARCH WIDGET BAR
        // ============================================================================
        Row {
            width: parent.width
            height: 40
            spacing: 10
            visible: listComp.searchVisible

            Rectangle {
                width: parent.width - 90
                height: parent.height
                color: listComp.listBgColor
                border.color: searchInput.activeFocus ? listComp.innerCardActiveBorder : listComp.itemBorderColor
                border.width: searchInput.activeFocus ? 2 : 1
                radius: 6

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "🔍"
                        font.pixelSize: listComp.textSubSize - 2
                        color: listComp.senderTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 30
                        font.family: listComp.listFontFamily
                        font.pixelSize: listComp.textSubSize - 2
                        color: listComp.subjectTextColor
                        anchors.verticalCenter: parent.verticalCenter

                        onTextChanged: {
                            listComp.searchQuery = text;
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                searchInput.text = "";
                                searchInput.focus = false;
                                listComp.searchVisible = false;
                                rootWindow.forceActiveFocus();
                                event.accepted = true;
                            }
                        }

                        Text {
                            text: "Search emails..."
                            color: listComp.itemBorderColor
                            visible: parent.text === ""
                            font.pixelSize: listComp.textSubSize - 2
                            font.family: listComp.listFontFamily
                        }
                    }
                }
            }

            Rectangle {
                width: 80
                height: parent.height
                color: listComp.searchCaseSensitive ? listComp.innerCardActiveBorder : listComp.listBgColor
                border.color: listComp.itemBorderColor
                border.width: 1
                radius: 6

                Text {
                    text: "Aa"
                    font.family: listComp.listFontFamily
                    font.pixelSize: listComp.textSubSize - 4
                    font.bold: true
                    color: listComp.searchCaseSensitive ? listComp.listBgColor : listComp.subjectTextColor
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        listComp.searchCaseSensitive = !listComp.searchCaseSensitive;
                    }
                }
            }
        }

        // ============================================================================
        // EMAILS LIST VIEW
        // ============================================================================
        ListView {
            id: internalListView
            width: parent.width
            height: parent.height - (listComp.searchVisible ? 52 : 0)
            model: listComp.mailItems
            spacing: 6
            currentIndex: listComp.activeMailIndex
            clip: true

            delegate: Rectangle {
                id: emailItemRect
                width: internalListView.width
                height: listComp.itemHeight
                radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                color: (index === listComp.activeMailIndex) ? listComp.itemSelectedBg : "transparent"
                border.color: (index === listComp.activeMailIndex) ? listComp.innerCardActiveBorder : listComp.itemBorderColor
                border.width: (index === listComp.activeMailIndex) ? listComp.innerCardActiveThickness : 1

                // 1. Helper function to check if this email is flagged/starred
                function isStarred() {
                    var flags = modelData.flags || [];
                    for (var i = 0; i < flags.length; i++) {
                        if (flags[i].toLowerCase() === "flagged") {
                            return true;
                        }
                    }
                    return false;
                }

                // 2. Helper function to check if this email is unread
                function isUnread() {
                    var flags = modelData.flags || [];
                    for (var i = 0; i < flags.length; i++) {
                        if (flags[i].toLowerCase() === "seen") {
                            return false; // has been seen
                        }
                    }
                    return true; // unseen / unread
                }

                // 3. Helper to generate consistent, unique avatar colors for senders
                function getAvatarColor(name) {
                    var hash = 0;
                    for (var i = 0; i < name.length; i++) {
                        hash = name.charCodeAt(i) + ((hash << 5) - hash);
                    }
                    var colors = ["#458588", "#b16286", "#689d6a", "#d3869b", "#8ec07c", "#fe8019", "#d65d0e"];
                    return colors[Math.abs(hash) % colors.length];
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Dynamic Sender Circle Avatar
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: emailItemRect.getAvatarColor(emailSenderText.text)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: emailSenderText.text.charAt(0).toUpperCase()
                            color: "#fbf1c7"
                            font.bold: true
                            font.pixelSize: listComp.textMainSize
                            font.family: listComp.listFontFamily
                            anchors.centerIn: parent
                        }
                    }

                    // Email Details column
                    Column {
                        width: parent.width - 130
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: emailSenderText
                            text: modelData.from ? (modelData.from.name || modelData.from.addr) : "Unknown Sender"
                            font.family: listComp.listFontFamily
                            font.pixelSize: listComp.textMainSize
                            font.bold: emailItemRect.isUnread() // Bold if unread
                            color: listComp.senderTextColor
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: modelData.subject || "(No Subject)"
                            font.family: listComp.listFontFamily
                            font.pixelSize: listComp.textSubSize
                            font.bold: emailItemRect.isUnread() // Bold if unread
                            color: listComp.subjectTextColor
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Blue Unread Circle indicator or Empty space
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#458588" // Gruvbox unread blue accent
                        anchors.verticalCenter: parent.verticalCenter
                        visible: emailItemRect.isUnread()

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                listComp.readToggled(index);
                            }
                        }
                    }

                    // Interactive Star Button
                    Text {
                        id: starIndicator
                        text: emailItemRect.isStarred() ? "★" : "☆"
                        font.pixelSize: listComp.textMainSize + 6
                        color: emailItemRect.isStarred() ? listComp.innerCardActiveBorder : listComp.itemBorderColor
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                listComp.starToggled(index);
                            }
                        }
                    }
                }
            }

            onCurrentIndexChanged: internalListView.positionViewAtIndex(currentIndex, ListView.Contain)
        }
    }
}
