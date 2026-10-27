import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var names: Stack.screens.map(s => s.name)
    readonly property bool custom: Settings.editing !== "" && Object.keys(Settings.values.screens[Settings.editing] || {}).length > 0

    visible: root.names.length > 1 || Settings.editing !== ""
    spacing: 6

    Row {
        anchors.right: parent.right
        spacing: 8

        RowButton {
            visible: root.custom
            icon: Icons.GLYPHS.restart
            label: "Reset " + Settings.editing
            onClicked: Settings.set("screens." + Settings.editing, {})
        }

        Segmented {
            width: Math.min(420, 110 + 96 * root.names.length)
            options: [
                {
                    key: "all",
                    label: "All screens"
                }
            ].concat(root.names.map(n => ({
                        key: n,
                        label: n
                    })))
            current: Settings.editing === "" ? "all" : Settings.editing
            onPicked: key => Settings.editing = key === "all" ? "" : key
        }
    }

    Text {
        textFormat: Text.PlainText
        anchors.right: parent.right
        visible: Settings.editing !== ""
        text: "Only on " + Settings.editing + ": bar, dock, panel spots, island spot and wallpaper look. Everything else stays shared."
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
    }
}
