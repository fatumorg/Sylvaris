import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.viewer
    readonly property bool on: Settings.shown.parts.viewer !== false

    spacing: 24

    Card {
        title: "Viewer"
        note: "Opens images and videos over the desktop. Step through the rest of the folder with the arrow keys or the scroll wheel, and copy, open in another app, show in the folder, set as the wallpaper or move to the trash from the bar at the bottom. Scripts and file managers use “sylvaris viewer open <file>”."

        Item {
            width: parent.width
            height: 220
            opacity: root.on ? 1 : 0.5

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Rectangle {
                anchors.centerIn: parent
                width: 220
                height: 124
                radius: Tokens.r(10)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.accentDeep
                    }
                    GradientStop {
                        position: 1
                        color: Theme.accent
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    text: Icons.GLYPHS.play
                    size: 34
                    color: Theme.onAccent
                }
            }

            Item {
                x: 12
                y: 12
                width: 150
                height: 26

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    raised: true
                    flowing: false
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "evening.mp4   3 / 12"
                    color: Theme.text
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.tinySize
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: tools.implicitWidth + 20
                height: 32

                Glass {
                    anchors.fill: parent
                    radius: Tokens.r(12)
                    raised: true
                    flowing: false
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Row {
                    id: tools
                    anchors.centerIn: parent
                    spacing: 12

                    Repeater {
                        model: [
                            {
                                glyph: Icons.GLYPHS.previous,
                                lit: false
                            },
                            {
                                glyph: Icons.GLYPHS.next,
                                lit: false
                            },
                            {
                                glyph: Icons.GLYPHS.pause,
                                lit: true
                            },
                            {
                                glyph: root.cfg.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume,
                                lit: root.cfg.muted
                            },
                            {
                                glyph: root.cfg.loop ? Icons.GLYPHS.repeat : Icons.GLYPHS.repeatOff,
                                lit: root.cfg.loop
                            },
                            {
                                glyph: Icons.GLYPHS.copy,
                                lit: false
                            },
                            {
                                glyph: Icons.GLYPHS.folder,
                                lit: false
                            },
                            {
                                glyph: Icons.GLYPHS.trash,
                                lit: false
                            }
                        ]

                        Glyph {
                            required property var modelData
                            text: modelData.glyph
                            size: 15
                            color: modelData.lit ? Theme.accent : Theme.text
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Use the viewer"
            subtitle: "The same switch: sylvaris set parts.viewer false"

            Toggle {
                checked: root.on
                onToggled: v => Settings.put("parts.viewer", v)
            }
        }

        SettingRow {
            title: "Play videos right away"

            Toggle {
                checked: root.cfg.autoplay
                enabled: root.on
                onToggled: v => Settings.put("viewer.autoplay", v)
            }
        }

        SettingRow {
            title: "Loop videos"

            Toggle {
                checked: root.cfg.loop
                enabled: root.on
                onToggled: v => Settings.put("viewer.loop", v)
            }
        }

        SettingRow {
            title: "Start videos muted"
            subtitle: "Press M in the viewer to switch"
            last: true

            Toggle {
                checked: root.cfg.muted
                enabled: root.on
                onToggled: v => Settings.put("viewer.muted", v)
            }
        }
    }

    Card {
        title: "Open files with SylViewer"
        note: "File managers open images and videos in SylViewer once it is the default app for them. With Home Manager set programs.sylvaris.defaultViewer = true. Elsewhere pick “SylViewer” under Open With in your file manager and tick “use as default”."
    }
}
