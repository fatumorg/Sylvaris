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
}
