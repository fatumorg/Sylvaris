import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.clip

    spacing: 24

    Card {
        title: "Clipboard"
        note: "Everything you copy is kept here so you can paste it again. Bind a key to “sylvaris clip toggle”. Passwords that password managers mark as secret are never kept."

        Item {
            width: parent.width
            height: 132

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Repeater {
                    model: [
                        {
                            text: "sylvaris switcher next",
                            pinned: true
                        },
                        {
                            text: "https://github.com/fatumorg/Sylvaris",
                            pinned: false
                        },
                        {
                            text: root.cfg.images ? "screenshot.png · image" : "Meet at 18:00 by the river",
                            pinned: false
                        }
                    ]

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 30

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusRow
                            inner: true
                            lit: index === 0
                        }

                        Text {
                            textFormat: Text.PlainText
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: index === 0 ? Theme.onAccent : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                        }

                        Glyph {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.pinned
                            text: Icons.GLYPHS.pin
                            size: 13
                            color: index === 0 ? Theme.onAccent : Theme.accent
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Items to keep"
            subtitle: "Pinned items are kept on top of this"

            Stepper {
                value: root.cfg.limit
                from: 5
                to: 500
                step: 5
                onStepped: v => Settings.put("clip.limit", v)
            }
        }

        SettingRow {
            title: "Keep images"
            subtitle: "Screenshots and copied pictures, stored in ~/.cache/sylvaris/clip"

            Toggle {
                checked: root.cfg.images
                onToggled: v => Settings.put("clip.images", v)
            }
        }

        SettingRow {
            title: "Remember after restart"
            subtitle: "Saves the history to ~/.local/state/sylvaris/clip.json"
            last: true

            Toggle {
                checked: root.cfg.persist
                onToggled: v => Settings.put("clip.persist", v)
            }
        }
    }
}
