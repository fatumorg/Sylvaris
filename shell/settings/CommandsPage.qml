import QtQuick
import SylStack
import qs.services
import "../lib/wm.mjs" as W
import "../lib/icons.mjs" as Icons

Column {
    required property var host

    spacing: 24

    Card {
        title: "Keybinds for " + (Compositor.name === "hyprland" ? (Compositor.usingLua ? "Hyprland (Lua)" : "Hyprland") : Compositor.name)
        note: "Every part of Sylvaris is a `sylvaris` command. Copy a line into your compositor config; the keys are only suggestions."

        Repeater {
            model: host.binds

            delegate: SettingRow {
                id: bindRow
                required property var modelData
                required property int index
                readonly property string line: W.bindSnippet(Compositor.name, Compositor.usingLua, modelData.key, modelData.command)
                title: modelData.label
                subtitle: line
                last: index === host.binds.length - 1

                Chip {
                    text: "Copy"
                    glyph: Icons.GLYPHS.copy
                    onClicked: Stack.clipboardText = bindRow.line
                }
            }
        }
    }

    Card {
        title: "Everything else"
        note: "`sylvaris list` prints every part and action, `sylvaris get` and `sylvaris set` read and change any setting on this screen, and `sylvaris watch` streams state changes for scripts."
    }
}
