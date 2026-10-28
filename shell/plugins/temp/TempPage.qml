import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/temp.mjs" as T
import "../../lib/icons.mjs" as Icons

Column {
    id: page

    required property var host
    property bool available: false
    readonly property var cfg: Settings.values.temp
    readonly property var bar: Settings.values.bar
    readonly property bool inBar: ["left", "center", "right"].some(side => page.bar[side].indexOf("temp") >= 0)

    function options(list: var): var {
        return list.map(k => ({
                    key: k,
                    label: k.charAt(0).toUpperCase() + k.slice(1).replace("-", " ")
                }));
    }

    function setBar(on: bool): void {
        for (const side of ["left", "center", "right"]) {
            const now = page.bar[side].filter(m => m !== "temp");
            if (on && side === "right")
                now.unshift("temp");
            if (now.length !== page.bar[side].length || on && side === "right")
                Settings.set("bar." + side, now);
        }
    }

    spacing: 24

    Process {
        running: true
        command: ["sh", "-c", "command -v tempinfo"]
        onExited: code => page.available = code === 0
    }

    Card {
        title: "SylTemp"
        note: page.available ? "Temperatures from TempInfoCLI, read only while the panel, the overlay, the bar chip or a widget is showing them." : "TempInfoCLI is not installed; get it from github.com/fatumorg/TempInfoCLI and it is picked up here."

        SettingRow {
            title: "Open SylTemp"
            key: "temp.open"
            subtitle: "Or run sylvaris temp toggle"

            Chip {
                text: "Open SylTemp"
                glyph: Icons.GLYPHS.thermometer
                onClicked: page.host.hand("temp", "")
            }
        }

        SettingRow {
            title: "Show in the bar"
            key: "temp.bar"
            subtitle: "The hottest pinned or headline sensor, coloured by how close it is to its limit"

            Toggle {
                checked: page.inBar
                onToggled: v => page.setBar(v)
            }
        }

        SettingRow {
            title: "Warn when something runs hot"
            key: "temp.alerts"
            subtitle: "A notification when a sensor reaches its hot limit"

            Toggle {
                checked: page.cfg.alerts
                onToggled: v => Settings.set("temp.alerts", v)
            }
        }

        SettingRow {
            title: "Warn again after"
            key: "temp.cooldown"
            advanced: true

            Stepper {
                value: Math.round(page.cfg.cooldown / 60)
                from: 1
                to: 60
                suffix: " min"
                onStepped: v => Settings.set("temp.cooldown", v * 60)
            }
        }

        SettingRow {
            title: "Read every"
            key: "temp.interval"
            advanced: true
            last: true

            Stepper {
                value: page.cfg.interval
                from: 1
                to: 10
                suffix: " s"
                onStepped: v => Settings.set("temp.interval", v)
            }
        }
    }

    Card {
        title: "Overlay"
        note: "A small readout over games and full-screen apps that never takes a click. Bind sylvaris temp overlay toggle to a key."

        SettingRow {
            title: "Show the overlay"
            key: "temp.overlay.show"
            subtitle: page.cfg.overlay.show === "apps" ? "Over the apps listed below" : page.cfg.overlay.show === "fullscreen" ? "Whenever a full-screen window has focus" : page.cfg.overlay.show === "toggle" ? "When you toggle it" : "Never"

            Segmented {
                width: 400
                options: page.options(T.SHOWS)
                current: page.cfg.overlay.show
                onPicked: key => Settings.set("temp.overlay.show", key)
            }
        }

        SettingRow {
            visible: page.cfg.overlay.show === "apps"
            title: "Over these apps"
            key: "temp.overlay.apps"
            subtitle: "Window classes, comma separated; patterns like steam_app_.* work"

            TextBox {
                width: 300
                text: page.cfg.overlay.apps.join(", ")
                placeholder: "steam_app_.*, gamescope"
                onAccepted: Settings.set("temp.overlay.apps", text.split(",").map(s => s.trim()).filter(s => s !== ""))
            }
        }

        SettingRow {
            title: "Style"
            key: "temp.overlay.style"

            Segmented {
                width: 360
                options: page.options(T.STYLES)
                current: page.cfg.overlay.style
                onPicked: key => Settings.set("temp.overlay.style", key)
            }
        }

        SettingRow {
            title: "Corner"
            key: "temp.overlay.corner"

            Segmented {
                width: 440
                options: page.options(T.OVERLAY_CORNERS)
                current: page.cfg.overlay.corner
                onPicked: key => Settings.set("temp.overlay.corner", key)
            }
        }

        SettingRow {
            title: "Size"
            key: "temp.overlay.scale"

            Slider {
                width: 260
                value: (page.cfg.overlay.scale - 0.5) / 2.5
                label: "×" + page.cfg.overlay.scale.toFixed(2)
                onMoved: v => Settings.set("temp.overlay.scale", Math.round((0.5 + v * 2.5) * 20) / 20)
            }
        }

        SettingRow {
            title: "Opacity"
            key: "temp.overlay.opacity"

            Slider {
                width: 260
                value: page.cfg.overlay.opacity
                label: Math.round(page.cfg.overlay.opacity * 100) + "%"
                onMoved: v => Settings.set("temp.overlay.opacity", Math.max(0.1, Math.round(v * 20) / 20))
            }
        }

        SettingRow {
            title: "Distance from the edge"
            key: "temp.overlay.offset"
            advanced: true
            last: true

            Row {
                spacing: 8

                Stepper {
                    value: page.cfg.overlay.x
                    from: 0
                    to: 400
                    step: 4
                    suffix: " px"
                    onStepped: v => Settings.set("temp.overlay.x", v)
                }

                Stepper {
                    value: page.cfg.overlay.y
                    from: 0
                    to: 400
                    step: 4
                    suffix: " px"
                    onStepped: v => Settings.set("temp.overlay.y", v)
                }
            }
        }
    }

    Card {
        title: "Pinned sensors"
        note: page.cfg.pinned.length === 0 ? "None yet. Pin sensors in the SylTemp panel and the overlay, bar chip and widgets show those instead of the CPU, graphics and hottest drive." : "The overlay, bar chip and widgets show these."

        Repeater {
            model: page.cfg.pinned

            delegate: SettingRow {
                required property string modelData
                required property int index
                title: modelData.replace(/^.*\//, "")
                subtitle: modelData.replace(/\/[^/]*$/, "")
                key: "temp.pinned." + modelData
                last: index === page.cfg.pinned.length - 1

                Chip {
                    text: "Unpin"
                    onClicked: Settings.set("temp.pinned", page.cfg.pinned.filter(id => id !== modelData))
                }
            }
        }
    }
}
