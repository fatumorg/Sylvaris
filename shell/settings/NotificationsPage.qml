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
            subtitle: "Only urgent notifications pop up; everything still lands in the notification center"

            Toggle {
                checked: Dnd.enabled
                onToggled: v => Dnd.setEnabled(v)
            }
        }

        SettingRow {
            title: "Toast duration"
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
