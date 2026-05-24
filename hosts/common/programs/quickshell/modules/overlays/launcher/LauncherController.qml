pragma Singleton

import QtQuick

Item {
    id: root

    /*
     * MODULE REFERENCES
     */

    property alias appLauncher: appLauncher
    property alias dictionary: dictionary
    property alias clipboard: clipboard

    /*
     * APP LAUNCHER
     */

    AppLauncher {
        id: appLauncher
    }

    /*
     * DICTIONARY
     */

    Dictionary {
        id: dictionary
    }

    /*
     * CLIPBOARD
     */

    Clipboard {
        id: clipboard
    }
}
