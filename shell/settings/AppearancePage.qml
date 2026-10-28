import QtQuick
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    required property var host

    spacing: 24

    Card {
        title: "Theme"

        SettingRow {
            title: Theme.theme.name || "Built-in"
            key: "theme"
            subtitle: Theme.theme.description || "The active theme"

            Chip {
                text: "Open the theme picker"
                glyph: Icons.GLYPHS.theme
                onClicked: host.hand("theme", "")
            }
        }

        SettingRow {
            title: "Theme-coloured app icons"
            key: "iconTint"
            subtitle: "App icons in the bar, deck, launcher, switcher and notifications take the theme's accent"

            Toggle {
                checked: Settings.shown.iconTint
                onToggled: v => Settings.put("iconTint", v)
            }
        }

        SettingRow {
            title: "Apply directly"
            key: "theme.apply"
            last: true

            Flow {
                width: 420
                spacing: 6
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: Theme.ids

                    delegate: Chip {
                        required property string modelData
                        text: Theme.catalog[modelData] !== undefined ? Theme.catalog[modelData].name : modelData
                        lit: modelData === Theme.currentId
                        onClicked: Theme.apply(modelData)
                    }
                }
            }
        }
    }

    Card {
        title: "Resin Glass"
        note: "Every panel, tile and card is drawn in translucent glass. Blur comes from your compositor."

        GlassPreview {}

        SettingRow {
            title: "Glass"
            key: "glass.enabled"
            subtitle: "Off brings back solid panels"

            Toggle {
                checked: Resin.enabled
                onToggled: v => Settings.put("glass.enabled", v)
            }
        }

        Repeater {
            model: host.glassKeys

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.label
                key: "glass." + modelData.key
                last: index === host.glassKeys.length - 1
                opacity: Resin.enabled ? 1 : 0.45

                Slider {
                    width: 300
                    value: host.glass(modelData.key) / modelData.max
                    label: host.glass(modelData.key).toFixed(modelData.max < 1 ? 3 : 2)
                    onMoved: v => Settings.put("glass." + modelData.key, Math.round(v * modelData.max * 1000) / 1000)
                }
            }
        }
    }
}
