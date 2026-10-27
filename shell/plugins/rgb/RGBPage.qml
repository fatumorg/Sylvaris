import QtQuick
import SylStack
import qs.services
import qs.components
import qs.settings
import "../../lib/rgb.mjs" as R
import "../../lib/icons.mjs" as Icons

Column {
    id: page

    required property var host
    readonly property var cfg: Settings.shown.rgb
    property var found: null

    spacing: 24

    function probe(): void {
        if (!lister.running)
            lister.running = true;
    }

    Component.onCompleted: page.probe()

    Process {
        id: lister
        command: ["python3", Stack.shellDir + "/helpers/rgb.py", page.cfg.host, String(page.cfg.port), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.found = JSON.parse(text);
                } catch (e) {
                    page.found = {
                        ok: false,
                        error: "the RGB helper did not answer"
                    };
                }
            }
        }
    }

    Card {
        title: "SylRGB"
        note: "Lights on every device OpenRGB can drive: mice, keyboards, headsets, memory, graphics cards, motherboards, coolers and LED strips. OpenRGB does the talking to the hardware; SylRGB decides the colours."

        SettingRow {
            title: page.found === null ? "Looking for OpenRGB…" : page.found.ok ? R.summary(page.cfg, page.found.devices.length, "") + " found" : "OpenRGB not running"
            subtitle: page.found === null ? "" : page.found.ok ? page.found.devices.map(d => d.name).join(", ") : page.found.error

            Row {
                spacing: 8

                Chip {
                    text: "Look again"
                    glyph: Icons.GLYPHS.restart
                    onClicked: page.probe()
                }

                Chip {
                    text: "Open Lighting"
                    glyph: Icons.GLYPHS.rgb
                    onClicked: page.host.hand("rgb", "")
                }
            }
        }

        SettingRow {
            last: true
            title: "Lights"
            subtitle: "Off turns every device dark until you switch it back"

            Toggle {
                checked: page.cfg.on
                onToggled: v => Settings.set("rgb.on", v)
            }
        }
    }

    Card {
        title: "Colour"
        note: "Want a colour just for the lights? Turn Follow the theme off and pick one in the Lighting panel, or run sylvaris rgb color ff2d55."

        SettingRow {
            title: "Follow the theme"
            subtitle: "Every device takes your theme's accent colour, and changes with it"

            Toggle {
                checked: page.cfg.follow
                onToggled: v => Settings.set("rgb.follow", v)
            }
        }

        SettingRow {
            title: "Vivid theme colours"
            subtitle: "Theme accents are soft on screen but look dull on LEDs, so SylRGB sends them at full strength. A theme can name its own LED colour with colors.rgb"

            Toggle {
                checked: page.cfg.vivid
                onToggled: v => Settings.set("rgb.vivid", v)
            }
        }

        SettingRow {
            title: "Brightness"
            subtitle: "Scales every colour SylRGB sends"

            Slider {
                width: 260
                value: page.cfg.brightness / 100
                label: page.cfg.brightness + "%"
                onMoved: v => Settings.set("rgb.brightness", Math.round(v * 100))
            }
        }

        SettingRow {
            last: true
            title: "Put the colours back"
            subtitle: "When Sylvaris starts and whenever a device reconnects, like a wireless mouse waking up"

            Toggle {
                checked: page.cfg.restore
                onToggled: v => Settings.set("rgb.restore", v)
            }
        }
    }

    Card {
        title: "OpenRGB server"
        note: "Turn on the SDK server in OpenRGB (the SDK Server tab, or openrgb --server). On NixOS: services.hardware.openrgb.enable = true."

        SettingRow {
            title: "Address"
            subtitle: "127.0.0.1 is this computer"

            TextBox {
                width: 180
                text: page.cfg.host
                placeholder: "127.0.0.1"
                onAccepted: Settings.set("rgb.host", text.trim() === "" ? "127.0.0.1" : text.trim())
            }
        }

        SettingRow {
            last: true
            title: "Port"
            subtitle: "6742 unless you changed it in OpenRGB"

            TextBox {
                width: 120
                text: String(page.cfg.port)
                placeholder: "6742"
                onAccepted: {
                    const n = parseInt(text, 10);
                    if (n >= 1 && n <= 65535)
                        Settings.set("rgb.port", n);
                }
            }
        }
    }
}
