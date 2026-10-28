import QtQuick
import qs.services
import qs.components
import qs.settings
import "../../lib/icons.mjs" as Icons

Column {
    id: diverColumn
    required property var host
    property string message: ""
    spacing: 24

    Connections {
        target: Diver
        function onPairFinished(ok, message) {
            diverColumn.message = message;
        }
    }

    Card {
        title: "SylDiver"
        note: Diver.paired ? "Connected. Plans show up in SylClock and SylCenter, timed plans pop up here when they start, earlier reminders arrive as notifications and alarms ring." + (Diver.error !== "" ? " Last problem: " + Diver.error : "") : "Open diver → settings → connected devices → connect sylvaris, then paste the whole line here. Your password never leaves the browser; Sylvaris only gets a key for your list and a token you can revoke."

        SettingRow {
            visible: Diver.paired || Demo.enabled
            title: "Your plans"
            key: "diver.plans"
            subtitle: "Today, calendar, lists and every task field, right here"

            Chip {
                text: "Open SylDiver"
                glyph: Icons.GLYPHS.planner
                onClicked: host.hand("diver", "")
            }
        }

        SettingRow {
            visible: !Diver.paired
            title: "Pairing code"
            key: "diver.pair"
            subtitle: diverColumn.message

            Row {
                spacing: 8

                TextBox {
                    id: codeBox
                    width: 300
                    placeholder: "sylvaris diver pair …"
                    onAccepted: Diver.pair(codeBox.text)
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !Diver.pairing
                    opacity: enabled ? 1 : 0.4
                    text: Diver.pairing ? "Pairing…" : "Pair"
                    glyph: Icons.GLYPHS.link
                    onClicked: {
                        if (codeBox.text.trim() !== "")
                            Diver.pair(codeBox.text);
                    }
                }
            }
        }

        SettingRow {
            visible: Diver.paired
            title: "Synced " + (Diver.lastSync > 0 ? Qt.formatTime(new Date(Diver.lastSync), "HH:mm:ss") : "not yet")
            key: "diver.sync"
            subtitle: Diver.agendaToday.length + " planned today" + (Diver.next !== null ? " · next: " + Diver.plain(Diver.next.task.text) + " at " + Qt.formatTime(new Date(Diver.next.start), "HH:mm") : "")

            Row {
                spacing: 8

                Chip {
                    enabled: !Diver.syncing
                    opacity: enabled ? 1 : 0.4
                    text: Diver.syncing ? "Syncing…" : "Sync now"
                    glyph: Icons.GLYPHS.restart
                    onClicked: Diver.sync()
                }

                Chip {
                    text: "Disconnect"
                    glyph: Icons.GLYPHS.disconnect
                    onClicked: Diver.unpair()
                }
            }
        }

        SettingRow {
            title: "Check for changes every"
            key: "diver.refresh"
            advanced: true
            last: true

            Stepper {
                value: Settings.values.diver.refresh
                from: 1
                to: 60
                suffix: " min"
                onStepped: v => Settings.set("diver.refresh", v)
            }
        }
    }

    Card {
        title: "Reminders"

        Repeater {
            model: [
                {
                    key: "calendar",
                    title: "Show plans in the calendars",
                    sub: "Dots on busy days, and the day's list when you click one"
                },
                {
                    key: "notify",
                    title: "Notifications",
                    sub: "A toast when a reminder is due"
                },
                {
                    key: "alarms",
                    title: "Alarms",
                    sub: "Timed plans take over the screen when they start; ones marked as alarms also ring until you snooze or finish them"
                },
                {
                    key: "sound",
                    title: "Alarm sound",
                    sub: "Rings for up to two minutes"
                }
            ]

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.title
                key: "diver." + modelData.key
                subtitle: modelData.sub
                last: index === 3

                Toggle {
                    checked: Settings.values.diver[modelData.key]
                    onToggled: v => Settings.set("diver." + modelData.key, v)
                }
            }
        }
    }

    Card {
        title: "Try it"

        SettingRow {
            title: "Ring a test alarm"
            key: "diver.alarmTest"
            subtitle: "Esc dismisses, Enter marks done, Space snoozes"
            last: true

            Chip {
                text: "Test"
                glyph: Icons.GLYPHS.alarm
                onClicked: {
                    host.close();
                    Diver.alarm = {
                        rid: "test",
                        id: "",
                        at: Date.now(),
                        start: Date.now(),
                        before: 0,
                        alarm: true,
                        title: "This is how a Diver alarm looks",
                        path: "test"
                    };
                }
            }
        }
    }
}
