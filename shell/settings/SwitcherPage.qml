import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.switcher

    spacing: 24

    Card {
        title: "Window switcher"
        note: "Bind Alt+Tab to “sylvaris switcher next” and Alt+Shift+Tab to “sylvaris switcher prev”. Keep Alt held and tap Tab to move; let go of Alt to jump to the window."

        Item {
            width: parent.width
            height: 150

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: [
                        {
                            glyph: Icons.GLYPHS.apps,
                            title: "Files"
                        },
                        {
                            glyph: Icons.GLYPHS.music,
                            title: "Music"
                        },
                        {
                            glyph: Icons.GLYPHS.planner,
                            title: "Diver"
                        }
                    ]

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: root.cfg.previews ? 130 : 84
                        height: root.cfg.previews ? 108 : root.cfg.titles ? 100 : 84

                        Behavior on width {
                            NumberAnimation {
                                duration: Tokens.moveDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.enterCurve
                            }
                        }

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusRow
                            inner: true
                            lit: index === 1
                        }

                        Rectangle {
                            x: 7
                            y: 7
                            width: parent.width - 14
                            height: root.cfg.previews ? 62 : parent.width - 14
                            radius: 8
                            color: root.cfg.previews ? Qt.alpha(Theme.text, 0.08) : "transparent"

                            Glyph {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                size: root.cfg.previews ? 22 : 34
                                color: index === 1 ? Theme.onAccent : Theme.accent
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            width: parent.width
                            visible: root.cfg.titles
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.title
                            color: index === 1 ? Theme.onAccent : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.tinySize
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Live previews"
            subtitle: "Show what each window looks like instead of only its icon"

            Toggle {
                checked: root.cfg.previews
                onToggled: v => Settings.put("switcher.previews", v)
            }
        }

        SettingRow {
            title: "Window titles"
            subtitle: "Name every card with its window title"
            last: true

            Toggle {
                checked: root.cfg.titles
                onToggled: v => Settings.put("switcher.titles", v)
            }
        }
    }
}
