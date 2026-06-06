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
    readonly property alias placeholder2: placeholder2
    readonly property alias placeholder3: placeholder3

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
/////// PLACEHOLDERS
   Email {
        id: email
    }

   Placeholder2 {
        id: placeholder2
    }

    Placeholder3 {
        id: placeholder3
    }


}
