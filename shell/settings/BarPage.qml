import QtQuick
import qs
import qs.services
import qs.components
import "../lib/bar.mjs" as B
import "../lib/icons.mjs" as Icons

Column {
    required property var host

    spacing: 24

    Card {
        title: "SylBar"

        MiniScreen {}

        SettingRow {
            title: "Show the bar"
            key: "bar.enabled"

            Toggle {
                checked: Settings.shown.bar.enabled
                onToggled: v => Settings.put("bar.enabled", v)
            }
        }

        SettingRow {
            title: "Edge"
            key: "bar.position"
            subtitle: "Where the bar sits; left and right make it vertical"

            Segmented {
                width: 320
                current: Settings.shown.bar.position
                options: B.POSITIONS.map(p => ({
                            key: p,
                            label: p.charAt(0).toUpperCase() + p.slice(1)
                        }))
                onPicked: key => Settings.put("bar.position", key)
            }
        }

        SettingRow {
            title: "Style"
            key: "bar.style"
            subtitle: "Separate glass islands for each side, or one continuous slab"

            Segmented {
                width: 240
                current: Settings.shown.bar.style
                options: [
                    {
                        key: "islands",
                        label: "Islands"
                    },
                    {
                        key: "slab",
                        label: "Slab"
                    }
                ]
                onPicked: key => Settings.put("bar.style", key)
            }
        }

        SettingRow {
            title: "Workspace icons"
            key: "bar.workspaceIcons"
            subtitle: Settings.shown.bar.workspaceIcons === "auto" ? "Follows the theme" + (Theme.theme.workspaceIcon ? " (" + Theme.theme.workspaceIcon + ")" : ", which picks numbers") : "The same everywhere"
        }

        Flow {
            width: parent.width
            spacing: 6
            bottomPadding: 8

            Repeater {
                model: B.WORKSPACE_LOOKS

                delegate: Chip {
                    required property string modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    glyph: B.WORKSPACE_ICONS[modelData] || ""
                    lit: Settings.shown.bar.workspaceIcons === modelData
                    onClicked: Settings.put("bar.workspaceIcons", modelData)
                }
            }
        }

        SettingRow {
            title: "Floating"
            key: "bar.floating"
            subtitle: "A gap around the bar, or one that touches the edge"
            last: true

            Toggle {
                checked: Settings.shown.bar.floating
                onToggled: v => Settings.put("bar.floating", v)
            }
        }
    }

    Card {
        title: "Modules"
        note: "Click a module to move it along or remove it; add the ones you are missing to any side. Tray apps live in a drawer behind the arrow." + (host.hasBattery ? "" : " This computer has no battery, so the battery module stays hidden and the rest fill its place.")

        Repeater {
            model: ["left", "center", "right"]

            delegate: Item {
                id: side
                required property string modelData
                property int picked: -1
                readonly property var list: Settings.shown.bar[modelData]
                width: parent.width
                height: sideFlow.implicitHeight + 50

                Text {
                    textFormat: Text.PlainText
                    y: 14
                    text: side.modelData.charAt(0).toUpperCase() + side.modelData.slice(1)
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Flow {
                    id: sideFlow
                    y: 38
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: side.list

                        delegate: Row {
                            required property string modelData
                            required property int index
                            spacing: 4

                            Chip {
                                text: modelData
                                opacity: modelData === "battery" && !host.hasBattery ? 0.35 : 1
                                lit: side.picked === index
                                onClicked: side.picked = side.picked === index ? -1 : index
                            }

                            Repeater {
                                model: side.picked === index ? [
                                    {
                                        glyph: Icons.GLYPHS.chevronLeft,
                                        act: -1
                                    },
                                    {
                                        glyph: Icons.GLYPHS.chevronRight,
                                        act: 1
                                    },
                                    {
                                        glyph: Icons.GLYPHS.close,
                                        act: 0
                                    }
                                ] : []

                                delegate: Chip {
                                    required property var modelData
                                    glyph: modelData.glyph
                                    onClicked: {
                                        const list = side.list;
                                        const i = side.picked;
                                        if (modelData.act === 0) {
                                            Settings.put("bar." + side.modelData, list.filter((m, k) => k !== i));
                                            side.picked = -1;
                                        } else {
                                            Settings.put("bar." + side.modelData, B.shift(list, i, modelData.act));
                                            side.picked = Math.max(0, Math.min(list.length - 1, i + modelData.act));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: B.unused(Settings.shown.bar)

                        delegate: Chip {
                            required property string modelData
                            readonly property bool dead: modelData === "battery" && !host.hasBattery
                            text: modelData
                            glyph: Icons.GLYPHS.plus
                            opacity: dead ? 0.25 : 0.6
                            enabled: !dead
                            onClicked: Settings.put("bar." + side.modelData, side.list.concat([modelData]))
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    visible: side.modelData !== "right"
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.text, 0.08)
                }
            }
        }
    }
}
