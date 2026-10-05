import QtQuick
import "../../../style" as Style

Item {
    id: listComp

    property color listBgColor: (typeof theme !== 'undefined' && theme) ? theme.base00 : "#121212"
    property color itemSelectedBg: (typeof theme !== 'undefined' && theme) ? theme.base00 : "#121212"
    property color itemBorderColor: (typeof theme !== 'undefined' && theme) ? theme.base01 : "#0f0f0f"
    property color senderTextColor: (typeof theme !== 'undefined' && theme) ? theme.base05 : "#f7f700"
    property color subjectTextColor: (typeof theme !== 'undefined' && theme) ? theme.base06 : "#ebdbb2"
    property int listPadding: (typeof theme !== 'undefined' && theme) ? theme.globalPadding : 16
    property int itemHeight: (typeof theme !== 'undefined' && theme ? theme.defaultCardHeight : 140) - 50
    property int textMainSize: (typeof theme !== 'undefined' && theme) ? theme.globalFontSize : 16
    property int textSubSize: (typeof theme !== 'undefined' && theme) ? theme.globalFontSize : 14
    property string listFontFamily: (typeof theme !== 'undefined' && theme) ? theme.fontFamily : "monospace"

    property color outerBorderColor: (typeof theme !== 'undefined' && theme) ? theme.outerBorderColor : "#003399"
    property color innerCardActiveBorder: (typeof theme !== 'undefined' && theme) ? theme.innerBorderColor : "#fabd2f"
    property int globalBorderWidth: (typeof theme !== 'undefined' && theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 3

    property var mailItems: []
    property int activeMailIndex: 0
    property bool searchVisible: false
    property string searchQuery: ""
    property bool searchCaseSensitive: false

    readonly property int searchFieldHeight: {
        if (typeof shell !== 'undefined' && shell && shell.settingsManager) {
            return shell.settingsManager.getWindowFieldHeight("email", 44);
        }
        return 44;
    }

    signal starToggled(int index)
    signal readToggled(int index)

    function toggleSearch() {
        searchVisible = !searchVisible;
        if (searchVisible) {
            Qt.callLater(() => searchInput.forceActiveFocus());
        } else {
            searchInput.text = "";
            internalListView.forceActiveFocus();
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: listComp.listPadding
        spacing: 12

        Item {
            id: searchBarRow
            width: parent.width
            height: listComp.searchVisible ? listComp.searchFieldHeight : 0
            visible: listComp.searchVisible
            clip: true

            Item {
                id: searchInputBox
                anchors.left: parent.left
                anchors.right: caseSensitiveBtn.left
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: listComp.listBgColor
                    borderColor: searchInput.activeFocus ? listComp.innerCardActiveBorder : listComp.itemBorderColor
                    borderWidth: searchInput.activeFocus ? listComp.globalBorderWidth : 1
                    slantWidth: 10
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        id: searchIcon
                        text: "🔍"
                        font.pixelSize: Math.max(14, listComp.textSubSize - 2)
                        color: listComp.senderTextColor
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: listComp.listFontFamily
                        font.pixelSize: Math.max(13, listComp.textSubSize)
                        color: listComp.subjectTextColor
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        clip: true
                        onTextChanged: listComp.searchQuery = text

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                searchInput.text = "";
                                listComp.searchVisible = false;
                                internalListView.forceActiveFocus();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search emails..."
                            color: "#666"
                            visible: parent.text === "" && !parent.activeFocus
                            font.pixelSize: Math.max(13, listComp.textSubSize)
                            font.family: listComp.listFontFamily
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item {
                id: caseSensitiveBtn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(64, aaText.implicitWidth + 24)

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 8
                    color: listComp.searchCaseSensitive ? listComp.innerCardActiveBorder : listComp.listBgColor
                    borderColor: listComp.itemBorderColor
                    borderWidth: listComp.searchCaseSensitive ? listComp.globalBorderWidth : 1
                }

                Text {
                    id: aaText
                    text: "Aa"
                    font.family: listComp.listFontFamily
                    font.pixelSize: Math.max(12, listComp.textSubSize - 2)
                    font.bold: true
                    color: listComp.searchCaseSensitive ? listComp.listBgColor : listComp.subjectTextColor
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: listComp.searchCaseSensitive = !listComp.searchCaseSensitive
                }
            }
        }

        ListView {
            id: internalListView
            width: parent.width
            height: parent.height - (listComp.searchVisible ? (listComp.searchFieldHeight + 12) : 0)
            model: listComp.mailItems
            spacing: 6
            currentIndex: listComp.activeMailIndex
            clip: true
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Delete) {
                    if (typeof viewRoot !== "undefined" && viewRoot.engine) {
                        viewRoot.engine.handleDeletion();
                    }
                    event.accepted = true;
                }
            }

            delegate: Item {
                id: emailItemRect
                width: internalListView.width
                height: listComp.itemHeight

                property bool isStarred: modelData.flags ? modelData.flags.map(f => f.toLowerCase()).includes("flagged") : false
                property bool isUnread: modelData.flags ? !modelData.flags.map(f => f.toLowerCase()).includes("seen") : true
                property bool hasAttachment: !!(modelData["has-attachment"] || modelData.has_attachment || (modelData.attachments && modelData.attachments.length > 0))

                function getAvatarColor(name) {
                    var hash = name.split("").reduce(function(acc, char) { return char.charCodeAt(0) + ((acc << 5) - acc); }, 0);
                    return ["#458588", "#b16286", "#689d6a", "#d3869b", "#8ec07c", "#fe8019", "#d65d0e"][Math.abs(hash) % 7];
                }

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 10
                    color: (index === listComp.activeMailIndex) ? listComp.itemSelectedBg : "transparent"
                    borderColor: (index === listComp.activeMailIndex) ? listComp.innerCardActiveBorder : listComp.itemBorderColor
                    borderWidth: (index === listComp.activeMailIndex) ? listComp.globalBorderWidth : 1
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: emailItemRect.getAvatarColor(emailSenderText.text)
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: emailSenderText.text.charAt(0).toUpperCase()
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 16
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        width: parent.width - 130
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: emailSenderText
                            text: modelData.from ? (modelData.from.name || modelData.from.addr) : "Unknown Sender"
                            font.family: listComp.listFontFamily
                            font.pixelSize: listComp.textMainSize
                            font.bold: emailItemRect.isUnread
                            color: listComp.senderTextColor
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Row {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "📎"
                                font.pixelSize: listComp.textSubSize - 4
                                color: listComp.subjectTextColor
                                visible: emailItemRect.hasAttachment
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.subject || "(No Subject)"
                                font.family: listComp.listFontFamily
                                font.pixelSize: listComp.textSubSize
                                font.bold: emailItemRect.isUnread
                                color: listComp.subjectTextColor
                                elide: Text.ElideRight
                                width: emailItemRect.hasAttachment ? parent.width - 20 : parent.width
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: "#458588"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: emailItemRect.isUnread
                        MouseArea { anchors.fill: parent; onClicked: listComp.readToggled(index) }
                    }

                    Text {
                        id: starIndicator
                        text: emailItemRect.isStarred ? "★" : "☆"
                        font.pixelSize: listComp.textMainSize + 4
                        color: emailItemRect.isStarred ? listComp.innerCardActiveBorder : listComp.itemBorderColor
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; onClicked: listComp.starToggled(index) }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {
                        listComp.activeMailIndex = index;
                    }
                }
            }
            onCurrentIndexChanged: internalListView.positionViewAtIndex(currentIndex, ListView.Contain)
        }
    }
}
