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

    property string searchQuery: ""
    property bool isRegexSearch: false
    property bool isImportantOnlyView: false


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

    // Custom helper signal to forcefully push interface updates across modules
    signal modelDataForceRefreshed()

    // Invoked by the lists to guarantee index syncs pass cleanly down to the core layout
    function updateActiveSelection(newIndex) {
        if (emails && newIndex >= 0 && newIndex < emails.length) {
            currentListIndex = newIndex;
            modelDataForceRefreshed();
        }
    }

    // Unified helper function to navigate up safely through your email array data
    function navigateUp() {
        if (isReplying || isComposing)
            return;

        if (currentListIndex > 0) {
            currentListIndex--;
            modelDataForceRefreshed();
        }
    }

    // Unified helper function to navigate down safely through your email array data
    function navigateDown() {
        if (isReplying || isComposing)
            return;

        if (emails && currentListIndex < emails.length - 1) {
            currentListIndex++;
            modelDataForceRefreshed();
        }
    }
}
