import QtQuick
import qs
import qs.services
import qs.components
import "../lib/access.mjs" as A
import "../lib/icons.mjs" as Icons

Column {
    id: root

    property var access: null
    readonly property var tools: root.access !== null ? root.access.tools : ({})
    readonly property var cfg: Settings.shown.access
    readonly property var can: A.supports(Compositor.name)
    readonly property var names: ({
            none: "Off",
            grayscale: "Grayscale",
            invert: "Invert",
            protanopia: "Red-weak",
            deuteranopia: "Green-weak",
            tritanopia: "Blue-weak"
        })

    spacing: 18

    Row {
        spacing: 10

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.GLYPHS.accessibility
            size: 22
            color: Theme.accent
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "Accessibility"
            color: Theme.text
            font.family: Tokens.fontDisplay
            font.pixelSize: Tokens.titleSize
            font.weight: Tokens.titleWeight
        }
    }

    Card {
        title: "Seeing"

        SettingRow {
            title: "Zoom"
            subtitle: root.can.zoom ? "Magnifies around the pointer · “sylvaris access zoom in/out”" : "Needs Hyprland"
            enabled: root.can.zoom
            opacity: enabled ? 1 : 0.5

            Slider {
                width: 240
                value: (root.cfg.zoom - 1) / 4
                label: "×" + root.cfg.zoom.toFixed(1)
                onMoved: v => Settings.put("access.zoom", Math.round((1 + v * 4) * 10) / 10)
            }
        }

        SettingRow {
            title: "Text size"
            subtitle: "Every Sylvaris panel"

            Slider {
                width: 240
                value: (root.cfg.text - 0.8) / 0.8
                label: Math.round(root.cfg.text * 100) + "%"
                onMoved: v => Settings.put("access.text", Math.round((0.8 + v * 0.8) * 20) / 20)
            }
        }

        SettingRow {
            title: "Pointer size"
            subtitle: root.cfg.cursor === 0 ? "Left as your system sets it" : root.cfg.cursor + " px"

            Segmented {
                width: 260
                options: [0, 32, 48, 64].map(n => ({
                            key: String(n),
                            label: n === 0 ? "System" : String(n)
                        }))
                current: String(root.cfg.cursor)
                onPicked: key => Settings.put("access.cursor", Number(key))
            }
        }

        SettingRow {
            title: "Colour filter"
            subtitle: root.can.filter ? "Shifts colours so they are easier to tell apart" : "Needs Hyprland"
            last: true
            enabled: root.can.filter
            opacity: enabled ? 1 : 0.5
        }

        Flow {
            width: parent.width
            spacing: 8
            enabled: root.can.filter
            opacity: enabled ? 1 : 0.5

            Repeater {
                model: A.FILTERS

                delegate: Chip {
                    required property string modelData
                    text: root.names[modelData]
                    lit: root.cfg.filter === modelData
                    onClicked: Settings.put("access.filter", modelData)
                }
            }
        }
    }

    Card {
        title: "Comfort"

        SettingRow {
            title: "Reduce motion"
            subtitle: "Panels appear without moving"

            Toggle {
                checked: Settings.shown.motion.reduced
                onToggled: v => Settings.put("motion.reduced", v)
            }
        }

        SettingRow {
            title: "Reduce transparency"
            subtitle: "Solid panels instead of frosted glass"
            last: !root.tools.orca && !root.tools["wvkbd-mobintl"]

            Toggle {
                checked: !Resin.enabled
                onToggled: v => Settings.put("glass.enabled", !v)
            }
        }

        SettingRow {
            visible: root.tools.orca === true
            title: "Screen reader"
            subtitle: "Orca reads out what is on screen"
            last: !root.tools["wvkbd-mobintl"]

            RowButton {
                icon: Icons.GLYPHS.speech
                label: "Start or stop"
                onClicked: root.access.toggleTool("orca", ["--replace"])
            }
        }

        SettingRow {
            visible: root.tools["wvkbd-mobintl"] === true
            title: "On-screen keyboard"
            last: true

            RowButton {
                icon: Icons.GLYPHS.keyboard
                label: "Show or hide"
                onClicked: root.access.toggleTool("wvkbd-mobintl", ["-L", "300"])
            }
        }
    }
}
