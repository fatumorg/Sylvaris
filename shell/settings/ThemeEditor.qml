import QtQuick
import qs
import qs.services
import qs.components

Column {
    id: root

    required property string themeId
    readonly property var theme: Theme.themeOf(root.themeId)
    property string picking: ""
    property string fault: ""
    readonly property var colorRows: [
        {
            key: "base",
            label: "Background",
            note: "The deepest layer, behind every panel"
        },
        {
            key: "surface",
            label: "Surface",
            note: "Solid panels, popups and cards"
        },
        {
            key: "accent",
            label: "Accent",
            note: "Switches, sliders, selections and focus"
        },
        {
            key: "accentHi",
            label: "Bright accent",
            note: "Hover and the lit parts of the accent"
        },
        {
            key: "accentDeep",
            label: "Deep accent",
            note: "Lines, outlines and the tint in the glass"
        },
        {
            key: "onAccent",
            label: "Text on the accent",
            note: "Labels drawn on top of the accent"
        },
        {
            key: "text",
            label: "Text",
            note: "Titles and everything you read first"
        },
        {
            key: "textSoft",
            label: "Soft text",
            note: "Values and quieter labels"
        },
        {
            key: "textDim",
            label: "Dim text",
            note: "Notes like this one"
        },
        {
            key: "danger",
            label: "Warning",
            note: "Errors and actions you cannot undo"
        }
    ]
    readonly property var alphaRows: [
        {
            key: "surface",
            label: "Solid panels",
            note: "How opaque panels are when glass is off"
        },
        {
            key: "glass",
            label: "Glass",
            note: "How much of the background colour the glass keeps"
        },
        {
            key: "line",
            label: "Lines",
            note: "Outlines and dividers"
        },
        {
            key: "tint",
            label: "Tint",
            note: "The accent wash on hover and in lists"
        }
    ]

    signal done

    function put(key: string, value: var): void {
        try {
            Theme.edit(root.themeId, key, value);
            root.fault = "";
        } catch (e) {
            root.fault = e.message;
        }
    }

    function hsl(key: string, part: int, v: real): void {
        const c = Qt.color(root.theme.colors[key]);
        const h = part === 0 ? v : Math.max(0, c.hslHue);
        const s = part === 1 ? v : c.hslSaturation;
        const l = part === 2 ? v : c.hslLightness;
        root.put("colors." + key, Qt.hsla(Math.min(h, 0.999), s, l, 1).toString());
    }

    spacing: 24

    Card {
        title: "Edit a theme"
        note: "Every change shows at once and is kept in themes/" + root.themeId + ".json."

        SettingRow {
            title: "Name"
            key: "theme.name"

            TextBox {
                width: 260
                text: root.theme.name
                placeholder: "My theme"
                onAccepted: root.put("name", text)
            }
        }

        SettingRow {
            title: "Description"
            key: "theme.description"

            TextBox {
                width: 260
                text: root.theme.description
                placeholder: "Moss and slate"
                onAccepted: root.put("description", text)
            }
        }

        SettingRow {
            title: "Wallpaper"
            key: "theme.wallpaper"
            subtitle: "A full path; empty keeps the wallpaper you have"

            Row {
                spacing: 8

                TextBox {
                    width: 260
                    text: root.theme.wallpaper
                    placeholder: "~/Pictures/wall.png"
                    onAccepted: root.put("wallpaper", text)
                }

                Chip {
                    text: "Use the current one"
                    onClicked: root.put("wallpaper", Look.wallPath)
                }
            }
        }

        SettingRow {
            title: "Finish editing"
            key: "theme.done"
            subtitle: root.fault
            last: true

            Chip {
                text: "Done"
                lit: true
                onClicked: root.done()
            }
        }
    }

    Card {
        title: "Colours"
        note: "Type a colour like #5fb3a1, or click a swatch to mix one."

        Repeater {
            model: root.colorRows

            delegate: Column {
                id: entry

                required property var modelData
                required property int index
                readonly property string hex: root.theme.colors[entry.modelData.key]
                readonly property color shade: entry.hex

                width: parent.width

                SettingRow {
                    title: entry.modelData.label
                    key: "theme.colors"
                    subtitle: entry.modelData.note
                    last: entry.index === root.colorRows.length - 1 && root.picking !== entry.modelData.key

                    Row {
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: height / 2
                            color: entry.shade
                            border.width: root.picking === entry.modelData.key ? 2 : 1
                            border.color: root.picking === entry.modelData.key ? Theme.accent : Theme.lineStrong

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: root.picking = root.picking === entry.modelData.key ? "" : entry.modelData.key
                            }
                        }

                        TextBox {
                            width: 120
                            text: entry.hex
                            placeholder: "#5fb3a1"
                            onAccepted: root.put("colors." + entry.modelData.key, text.trim())
                        }
                    }
                }

                Repeater {
                    model: root.picking === entry.modelData.key ? ["Hue", "Saturation", "Lightness"] : []

                    delegate: SettingRow {
                        id: mix

                        required property string modelData
                        required property int index
                        readonly property real amount: mix.index === 0 ? Math.max(0, entry.shade.hslHue) : mix.index === 1 ? entry.shade.hslSaturation : entry.shade.hslLightness

                        title: mix.modelData
                        key: "theme.colors"
                        last: entry.index === root.colorRows.length - 1 && mix.index === 2

                        Slider {
                            width: 300
                            value: mix.amount
                            label: mix.index === 0 ? Math.round(mix.amount * 360) + "°" : Math.round(mix.amount * 100) + "%"
                            onMoved: v => root.hsl(entry.modelData.key, mix.index, v)
                        }
                    }
                }
            }
        }
    }

    Card {
        title: "Glass levels"

        Repeater {
            model: root.alphaRows

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.label
                key: "theme.alpha"
                subtitle: modelData.note
                last: index === root.alphaRows.length - 1

                Slider {
                    width: 300
                    value: root.theme.alpha[modelData.key]
                    label: Math.round(root.theme.alpha[modelData.key] * 100) + "%"
                    onMoved: v => root.put("alpha." + modelData.key, v)
                }
            }
        }
    }
}
