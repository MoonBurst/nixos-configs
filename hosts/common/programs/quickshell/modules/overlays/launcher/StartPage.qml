import QtQuick
import QtQuick.Controls

Rectangle {
    id: pageRoot

    property string query: ""

    anchors.fill: parent
    radius: theme.defaultCardRadius * 3 // 3x scaled corner radius relative to your Stylix layout rules

    // Dynamic Stylix Colors: base01 is your primary background ("#0F0F0F")
    color: theme.base01

    function updateSearch(text) {
        pageRoot.query = text
    }

    function openSearch() {
        const trimmed = query.trim()
        if (trimmed.length === 0)
            return

            const encoded = encodeURIComponent(trimmed)
            Qt.openUrlExternally("https://startpage.com" + encoded)
    }

    /*
     * MAIN HERO CONTAINER (DYNAMIC STYLIX WRAPPER)
     */
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: theme.globalPadding
        anchors.bottomMargin: theme.globalPadding
        anchors.leftMargin: theme.globalPadding * 1.2
        anchors.rightMargin: theme.globalPadding * 1.2

        radius: theme.defaultCardRadius * 3

        // base00 is your secondary container background ("#1a1a1a")
        color: theme.base00

        border.width: theme.globalBorderWidth
        // Glows with base03 ("#003399") when typing, drops to muted base02 ("#1a1a1a") when inactive
        border.color: pageRoot.query.length > 0 ? theme.base03 : theme.base02

        Behavior on border.color { ColorAnimation { duration: 150 } }

        /*
         * 3X SCALED CENTERED BUTTON
         */
        Button {
            id: searchActionButton
            anchors.centerIn: parent

            // Protect bounds using your theme's default layout properties
            width: Math.min(parent.width - (theme.globalPadding * 2.4), theme.defaultCardWidth * 1.7)
            height: theme.defaultCardHeight

            background: Rectangle {
                // Button color changes smoothly to base04 when hovered, uses active accent base03 ("#003399") natively
                color: parent.hovered ? theme.base04 : theme.base03
                radius: theme.defaultCardRadius * 2
            }

            contentItem: Text {
                text: pageRoot.query.length > 0 ? "Search " + pageRoot.query : "Launch Search"

                // base05 is your primary high-visibility yellow text color ("#F7F700")
                color: theme.base05

                // Configures the font face directly to match your system-wide Stylix sansSerif configuration ("Fira Sans")
                font.family: theme.fontFamily
                font.pixelSize: theme.globalFontSize * 2.25 // Boldly scales up your text
                font.bold: true

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            onClicked: pageRoot.openSearch()
        }
    }
}
