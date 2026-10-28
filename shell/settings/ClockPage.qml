import QtQuick
import qs
import qs.services

Column {
    required property var host

    spacing: 24

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
