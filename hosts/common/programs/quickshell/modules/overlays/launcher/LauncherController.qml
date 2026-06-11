pragma Singleton
import "./Email"

import QtQuick

Item {
    id: root

    /*
     * MODULE REFERENCES
     */

    readonly property alias appLauncher: appLauncher
    readonly property alias dictionary: dictionary
    readonly property alias clipboard: clipboard
    readonly property alias unicodeSearch: unicodeSearch
    readonly property alias startPage: startPage
    readonly property alias email: email
    readonly property alias todo:todo

    /*
     * MATH ENGINE
     */

    readonly property
    var mathEngine: MathEngine

    /*
     * MODULE INSTANCES
     */

    AppLauncher {
        id: appLauncher
    }

    Dictionary {
        id: dictionary
    }

    Clipboard {
        id: clipboard
    }

    UnicodeSearch {
        id: unicodeSearch
    }

    StartPage {
        id: startPage
    }

    Email {
        id: email
    }

    Todo {
        id: todo
    }


}
