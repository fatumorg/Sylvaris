import QtQuick
import qs.services
import qs.components
import "../lib/power.mjs" as Pw
import "../lib/icons.mjs" as Icons

Column {
    required property var host

    spacing: 24

    Card {
        title: "SylPower"
        note: "Put the power button on the bar (the power module), on the deck, or both. Commands can be replaced under power.commands in config.json."

        PowerPreview {}

        SettingRow {
            title: "Actions"
            key: "power.actions"
            subtitle: "Shown in this order"

            Flow {
                width: 420
                spacing: 6

                Repeater {
                    model: Object.keys(Pw.ACTIONS)

                    delegate: Chip {
                        required property string modelData
                        readonly property bool on: Settings.shown.power.actions.indexOf(modelData) >= 0
                        text: Pw.ACTIONS[modelData].label
                        glyph: Icons.GLYPHS[Pw.ACTIONS[modelData].glyph]
                        lit: on
                        onClicked: {
                            const list = Settings.shown.power.actions;
                            const order = Object.keys(Pw.ACTIONS);
                            const next = on ? list.filter(a => a !== modelData) : list.concat([modelData]).sort((x, y) => order.indexOf(x) - order.indexOf(y));
                            if (next.length > 0)
                                Settings.put("power.actions", next);
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Ask before closing everything"
            key: "power.confirm"
            subtitle: "Log out, restart, shut down and hibernate wait for a countdown"

            Toggle {
                checked: Settings.shown.power.confirm
                onToggled: v => Settings.put("power.confirm", v)
            }
        }

        SettingRow {
            title: "Countdown"
            key: "power.countdown"
            advanced: true
            last: true

            Stepper {
                value: Settings.shown.power.countdown
                from: 1
                to: 10
                suffix: " s"
                onStepped: v => Settings.put("power.countdown", v)
            }
        }
    }
}
