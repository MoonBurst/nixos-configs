import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 800
    height: 600
    title: "Email Preview"

    Column {
        anchors.fill: parent

        // Left side for email list (assuming you have a ListView or similar)
        ListView {
            id: emailListView
            width: parent.width / 2
            height: parent.height
            model: EmailModel
            delegate: Text {
                text: title
                onClicked: {
                    currentEmailIndex = index
                    updateEmailContent()
                }
            }
        }

        // Right side for email content display
        Rectangle {
            id: emailContentRect
            width: parent.width / 2
            height: parent.height
            border.color: "gray"
            border.width: 1

            Text {
                id: emailContentText
                anchors.fill: parent
                text: currentEmailContent
                wrapMode: Text.WrapWord
                font.pixelSize: 14
            }
        }
    }

    property int currentEmailIndex: -1
    property string currentEmailContent: ""

    function updateEmailContent() {
        if (currentEmailIndex !== -1) {
            currentEmailContent = getEmailContent(currentEmailIndex)
        } else {
            currentEmailContent = "No email selected"
        }
    }

    // Example model for email list
    ListModel {
        id: EmailModel
        ListElement { title: "Email 1" }
        ListElement { title: "Email 2" }
        ListElement { title: "Email 3" }
    }

    // Example function to fetch email content (replace with actual implementation)
    function getEmailContent(index) {
        if (index === 0) {
            return "This is the content of Email 1."
        } else if (index === 1) {
            return "This is the content of Email 2."
        } else if (index === 2) {
            return "This is the content of Email 3."
        }
        return ""
    }
}
