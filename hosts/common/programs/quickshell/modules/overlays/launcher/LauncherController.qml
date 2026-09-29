pragma Singleton
import "../rng"
import QtQuick

Item {
    id: root

    readonly property alias appLauncher: appLauncher
    readonly property alias dictionary: dictionary
    readonly property alias clipboard: clipboard
    readonly property alias unicodeSearch: unicodeSearch
    readonly property alias rng: rng

    AppLauncher { id: appLauncher }
    Dictionary { id: dictionary }
    Clipboard { id: clipboard }
    UnicodeSearch { id: unicodeSearch }
    Rng { id: rng }
}
