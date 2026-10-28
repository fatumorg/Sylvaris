import QtQuick
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/paper.mjs" as W

Column {
    required property var host

    spacing: 24

    Card {
        title: "SylPaper"
        note: "The wallpaper follows the theme. Pick another image for a theme or for one screen in the picker."

        PaperPreview {}

        SettingRow {
            title: "Draw the wallpaper"
            key: "paper.enabled"
            subtitle: "Turn off if another program such as hyprpaper draws it"

            Toggle {
                checked: Settings.shown.paper.enabled
                onToggled: v => Settings.put("paper.enabled", v)
            }
        }

        SettingRow {
            title: "Pick an image"
            key: "paper.folder"
            subtitle: Settings.shown.paper.folder

            Chip {
                text: "Open picker"
                glyph: Icons.GLYPHS.image
                onClicked: host.hand("paper", "")
            }
        }

        SettingRow {
            title: "Transition"
            key: "paper.transition"

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
            key: "paper.duration"
            advanced: true
            last: true

            Slider {
                width: 300
                value: Settings.shown.paper.duration / 3000
                label: (Settings.shown.paper.duration / 1000).toFixed(1) + " s"
                onMoved: v => Settings.put("paper.duration", Math.round(v * 30) * 100)
            }
        }
    }

    Card {
        title: "Look"
        note: "The same sliders sit in the wallpaper picker; with a screen picked above they change only that screen."

        SettingRow {
            title: "Fit"
            key: "paper.fit"

            Segmented {
                width: 320
                current: Settings.shown.paper.fit
                options: W.FITS.map(f => ({
                            key: f,
                            label: f.charAt(0).toUpperCase() + f.slice(1)
                        }))
                onPicked: key => Settings.put("paper.fit", key)
            }
        }

        SettingRow {
            title: "Blur"
            key: "paper.blur"

            Slider {
                width: 300
                value: Settings.shown.paper.blur
                label: Math.round(Settings.shown.paper.blur * 100) + "%"
                onMoved: v => Settings.put("paper.blur", Math.round(v * 100) / 100)
            }
        }

        SettingRow {
            title: "Dim"
            key: "paper.dim"

            Slider {
                width: 300
                value: Settings.shown.paper.dim / 0.9
                label: Math.round(Settings.shown.paper.dim * 100) + "%"
                onMoved: v => Settings.put("paper.dim", Math.round(v * 90) / 100)
            }
        }

        SettingRow {
            title: "Tint"
            subtitle: "Colours the image with the accent"
            key: "paper.tint"

            Slider {
                width: 300
                value: Settings.shown.paper.tint
                label: Math.round(Settings.shown.paper.tint * 100) + "%"
                onMoved: v => Settings.put("paper.tint", Math.round(v * 100) / 100)
            }
        }

        SettingRow {
            title: "Parallax"
            subtitle: "How far the wallpaper sways when you switch workspace"
            key: "paper.parallax"
            last: true

            Slider {
                width: 300
                value: Settings.values.paper.parallax
                label: Settings.values.paper.parallax === 0 ? "Still" : Math.round(Settings.values.paper.parallax * 100) + "%"
                onMoved: v => Settings.set("paper.parallax", Math.round(v * 20) / 20)
            }
        }
    }
}
