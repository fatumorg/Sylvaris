import QtQuick
import qs.services
import qs.components
import "../lib/eq.mjs" as E
import "../lib/icons.mjs" as Icons

Column {
    required property var host

    spacing: 24

    Card {
        title: "Output"

        Repeater {
            model: Audio.sinks

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.name
                key: "sound.output"
                last: index === Audio.sinks.length - 1

                Chip {
                    text: modelData.current ? "In use" : "Use"
                    lit: modelData.current
                    onClicked: Audio.setDefault(modelData.key)
                }
            }
        }
    }

    Card {
        title: "Equalizer"

        SettingRow {
            title: "Equalizer"
            key: "media.eq"
            subtitle: "Preset: " + E.PRESET_NAMES[Equalizer.cfg.preset]

            Row {
                spacing: 10

                Chip {
                    text: "Adjust"
                    glyph: Icons.GLYPHS.equalizer
                    onClicked: host.hand("media", "sound")
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Equalizer.cfg.enabled
                    onToggled: v => Equalizer.set({
                            enabled: v
                        })
                }
            }
        }

        SettingRow {
            title: "Spatial audio"
            key: "media.eq.spatial"
            subtitle: "Headphone crossfeed"
            last: true

            Toggle {
                checked: Equalizer.cfg.spatial
                onToggled: v => Equalizer.set({
                        spatial: v
                    })
            }
        }
    }

    Card {
        title: "UI sounds"
        note: "Put toggle, open, close and notify files (.oga, .ogg, .wav or .flac) in a folder; any you leave out stay quiet."

        SettingRow {
            title: "UI sounds"
            key: "sounds.enabled"
            subtitle: "Play a short sound for toggles, panels and notifications"

            Toggle {
                checked: Settings.shown.sounds.enabled
                onToggled: v => Settings.put("sounds.enabled", v)
            }
        }

        SettingRow {
            title: "Sound pack"
            key: "sounds.pack"
            subtitle: "The folder with the sounds"

            TextBox {
                width: 300
                text: Settings.shown.sounds.pack
                placeholder: "~/.local/share/sounds/sylvaris"
                onAccepted: Settings.put("sounds.pack", text.trim())
            }
        }

        SettingRow {
            title: "Sound volume"
            key: "sounds.volume"
            last: true

            Slider {
                width: 300
                value: Settings.shown.sounds.volume
                label: Math.round(Settings.shown.sounds.volume * 100) + "%"
                onMoved: v => Settings.put("sounds.volume", Math.round(v * 100) / 100)
            }
        }
    }
}
