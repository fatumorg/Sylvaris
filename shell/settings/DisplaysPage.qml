import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/virtual.mjs" as V

Column {
    required property var host

    spacing: 24

    Card {
        title: "Night light"

        SettingRow {
            title: "Night light"
            subtitle: NightLight.available ? "Warmer colours through wlsunset" : "Install wlsunset to use night light"

            Toggle {
                checked: NightLight.enabled
                onToggled: v => NightLight.setEnabled(v)
            }
        }

        SettingRow {
            title: "Colour temperature"
            last: true

            Slider {
                width: 300
                value: (NightLight.temperature - 2500) / 4000
                label: NightLight.temperature + " K"
                onMoved: v => Settings.put("nightLight.temperature", Math.round((2500 + v * 4000) / 100) * 100)
            }
        }
    }

    Card {
        title: "Screens"

        SettingRow {
            title: "Arrange displays"
            subtitle: "Resolution, refresh rate, scale and position, with automatic revert"

            Chip {
                text: "Open"
                glyph: Icons.GLYPHS.displays
                onClicked: host.hand("center", "displays")
            }
        }

        SettingRow {
            title: "Virtual display"
            subtitle: !VirtualDisplay.supported ? "Needs Hyprland" : !VirtualDisplay.available ? "Install wayvnc and wlr-randr to use a virtual display" : VirtualDisplay.error !== "" ? VirtualDisplay.error : "An extra screen for a tablet, shared over VNC on port " + VirtualDisplay.vnc.port

            Toggle {
                enabled: VirtualDisplay.available && !VirtualDisplay.busy
                checked: VirtualDisplay.active
                onToggled: v => v ? VirtualDisplay.start() : VirtualDisplay.stop()
            }
        }

        SettingRow {
            title: "Virtual display size"
            last: true

            Segmented {
                width: 420
                options: V.PRESETS.map(p => ({
                            key: p.width + "x" + p.height,
                            label: p.label
                        }))
                current: VirtualDisplay.width + "x" + VirtualDisplay.height
                onPicked: key => VirtualDisplay.setSize(Number(key.split("x")[0]), Number(key.split("x")[1]))
            }
        }
    }
}
