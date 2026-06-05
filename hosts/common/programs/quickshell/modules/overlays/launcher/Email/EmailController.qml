import QtCore
import QtQuick

QtObject {
    id: controller

    property string userEmailAddress: ""

    property var emails: []
    property var messageCache: ({})

    property string selectedId: ""
    property string messageBody: ""

    property string statusMessage: "Loading..."

    property bool isReplying: false
    property bool isComposing: false

    property string currentReplyTo: ""
    property string currentSubject: ""

    property string replyText: ""

    property string composeToAddress: ""
    property string composeSubject: ""
    property string composeBodyText: ""

    property int currentListIndex: 0

    property var contactDirectoryList: []

    property int globalFontSize: 20
    property int globalHeaderSize: 20
    property string fontFamily: "Fira Sans"

    property int defaultCardWidth: 420
    property int defaultCardHeight: 140
    property int defaultCardRadius: 10

    property int globalBorderWidth: 3
    property int globalPadding: 20
}
