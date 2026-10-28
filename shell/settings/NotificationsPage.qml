import QtQuick
import qs.services
import qs.components

Column {
    required property var host

    spacing: 24

    Card {
        title: "SylNotify"

        NotifyPreview {}

        SettingRow {
            title: "Do not disturb"
            key: "notifications.dnd"
            subtitle: "Only urgent notifications pop up; everything still lands in the notification center"

            Toggle {
                checked: Dnd.enabled
                onToggled: v => Dnd.setEnabled(v)
            }
        }

        SettingRow {
            title: "Stack"
            key: "notifications.stack"
            subtitle: "One under another, or a fanned deck that spreads when you point at it"

            Segmented {
                width: 220
                current: Settings.shown.notifications.stack
                options: [
                    {
                        key: "list",
                        label: "List"
                    },
                    {
                        key: "cards",
                        label: "Cards"
                    }
                ]
                onPicked: key => Settings.put("notifications.stack", key)
            }
        }

        SettingRow {
            title: "Toast duration"
            key: "notifications.timeout"
            subtitle: "Unless the app asks for something else"
            last: true

            Slider {
                width: 300
                value: (Settings.shown.notifications.timeout - 1000) / 59000
                label: (Settings.shown.notifications.timeout / 1000).toFixed(0) + " s"
                onMoved: v => Settings.put("notifications.timeout", Math.round(1000 + v * 59) * 1000)
            }
        }
    }

    Card {
        title: "Daemon"
        note: Notifications.enabled ? "Sylvaris is your notification daemon. Stop swaync, mako or dunst so it can receive notifications." : "notifications.server is false in config.json, so another daemon handles notifications."
    }
}
