import QtQuick
import qs
import qs.services
import qs.components
import qs.keyboard
import "../lib/keyboard.mjs" as K
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.keyboard
    readonly property bool on: Settings.shown.parts.keyboard
    readonly property var rows: K.rowsFor(root.cfg.layout, "letters")
    readonly property real unit: Math.round(30 * root.cfg.size)

    spacing: 24

    Card {
        title: "On-screen keyboard"
        note: "Type into any app without a keyboard nearby, for a computer on a TV. Click keys with a mouse, or move across them with a gamepad's d-pad or a TV remote's arrows and press OK; text you type that way waits in a line above the keys until you press Start or Enter. Select and Start together open and close it."

        Item {
            width: parent.width
            height: preview.height + 32

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Column {
                id: preview
                anchors.centerIn: parent
                spacing: Math.round(root.unit / 9)
                opacity: root.on ? 1 : 0.5

                Repeater {
                    model: root.rows.length

                    Row {
                        id: line
                        required property int index
                        spacing: Math.round(root.unit / 9)

                        Repeater {
                            model: root.rows[line.index].length

                            KeyCap {
                                required property int index
                                readonly property var key: root.rows[line.index][index]
                                width: key.width * root.unit
                                height: root.unit
                                label: K.labelFor(key, false, false)
                                focused: line.index === 2 && index === 1
                                enabled: false
                                opacity: 1
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Use the on-screen keyboard"
            key: "parts.keyboard"
            subtitle: "Off by default. The same switch: sylvaris set parts.keyboard true"

            Toggle {
                checked: root.on
                onToggled: v => Settings.put("parts.keyboard", v)
            }
        }

        SettingRow {
            title: "Layout"
            key: "keyboard.layout"
            subtitle: "What the keys show; typing works with any system layout"

            Segmented {
                width: 300
                options: Object.keys(K.LAYOUTS).map(id => ({
                            key: id,
                            label: K.LAYOUTS[id].name
                        }))
                current: root.cfg.layout
                onPicked: key => Settings.put("keyboard.layout", key)
            }
        }

        SettingRow {
            title: "Key size"
            key: "keyboard.size"

            Slider {
                width: 240
                value: (root.cfg.size - 0.6) / 1
                label: Math.round(root.cfg.size * 100) + "%"
                onMoved: v => Settings.put("keyboard.size", Math.round((0.6 + v) * 20) / 20)
            }
        }

        SettingRow {
            title: "Gamepads"
            key: "keyboard.gamepad"
            subtitle: "Move across the keys with a d-pad or stick; A presses, B closes, X deletes, Y adds a space"

            Toggle {
                checked: root.cfg.gamepad
                onToggled: v => Settings.put("keyboard.gamepad", v)
            }
        }

        SettingRow {
            title: "Select and Start open it"
            key: "keyboard.combo"
            last: true

            Toggle {
                checked: root.cfg.combo
                onToggled: v => Settings.put("keyboard.combo", v)
            }
        }
    }

    RowButton {
        visible: root.on
        icon: Icons.GLYPHS.keyboard
        label: "Show the keyboard"
        onClicked: Ipc.run(["keyboard", "toggle"])
    }
}
