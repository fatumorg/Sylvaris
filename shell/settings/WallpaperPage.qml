import QtQuick
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    required property var host

    spacing: 24

    Card {
        title: "SylPaper"
        note: "The wallpaper follows the theme. Pick another image for a theme or for one screen in the picker."

        PaperPreview {}

        SettingRow {
            title: "Draw the wallpaper"
            subtitle: "Turn off if another program such as hyprpaper draws it"

            Toggle {
                checked: Settings.shown.paper.enabled
                onToggled: v => Settings.put("paper.enabled", v)
            }
        }

        SettingRow {
            title: "Pick an image"
            subtitle: Settings.shown.paper.folder

            Chip {
                text: "Open picker"
                glyph: Icons.GLYPHS.image
                onClicked: host.hand("paper", "")
            }
        }

        SettingRow {
            title: "Transition"

            Segmented {
                width: 320
                current: Settings.shown.paper.transition
                options: ["zoom", "fade", "slide", "none"].map(k => ({
                            key: k,
                            label: k.charAt(0).toUpperCase() + k.slice(1)
                        }))
                onPicked: key => Settings.put("paper.transition", key)
            }
        }

        SettingRow {
            title: "Transition length"
            last: true

            Slider {
                width: 300
                value: Settings.shown.paper.duration / 3000
                label: (Settings.shown.paper.duration / 1000).toFixed(1) + " s"
                onMoved: v => Settings.put("paper.duration", Math.round(v * 30) * 100)
            }
        }
    }
}
