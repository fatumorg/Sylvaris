import QtQuick
import qs
import qs.services
import qs.components
import "../lib/calendar.mjs" as Cal

Column {
    required property var host

    spacing: 24

    Card {
        title: "Time"

        SettingRow {
            title: "Time format"
            key: "clock.format"
            subtitle: "For the bar, SylClock, the island, Control Center, Diver, the lock screen and sky widgets; clock widgets keep their own option"
            last: true

            Segmented {
                width: 260
                current: Settings.shown.clock.format
                options: Cal.HOURS.map(h => ({
                            key: h,
                            label: h === "12h" ? "12-hour" : "24-hour"
                        }))
                onPicked: key => Settings.put("clock.format", key)
            }
        }
    }

    Card {
        title: "Location"
        note: "SylClock uses your location for the sun and moon. Set `location = { latitude = …; longitude = …; }` in config.json or your Nix config to override the time zone guess."

        SettingRow {
            title: "Source"
            key: "sky.source"

            Text {
                textFormat: Text.PlainText
                text: Sky.source === "config" ? "config.json" : Sky.source === "timezone" ? "Time zone (" + Sky.zone + ")" : "Unknown"
                color: Theme.textSoft
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
            }
        }

        SettingRow {
            title: "Coordinates"
            key: "sky.place"
            last: true

            Text {
                textFormat: Text.PlainText
                text: Sky.available ? Sky.latitude.toFixed(2) + ", " + Sky.longitude.toFixed(2) : "—"
                color: Theme.textSoft
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.bodySize
            }
        }
    }
}
