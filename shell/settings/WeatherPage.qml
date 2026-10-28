import QtQuick
import qs.services
import qs.components

Column {
    required property var host

    spacing: 24

    Card {
        title: "Weather"
        note: Weather.error !== "" ? Weather.error : Weather.available ? "Now " + Weather.data.temp + Weather.data.unit + ", " + Weather.now.label.toLowerCase() + ". Forecasts come from Open-Meteo for the location below." : "Forecasts come from Open-Meteo for the location below."

        SettingRow {
            title: "Show the weather"
            key: "weather.enabled"
            subtitle: "In SylClock, refreshed in the background"

            Toggle {
                checked: Settings.shown.weather.enabled
                onToggled: v => Settings.put("weather.enabled", v)
            }
        }

        SettingRow {
            title: "Units"
            key: "weather.units"

            Segmented {
                width: 240
                current: Settings.shown.weather.units
                options: [
                    {
                        key: "metric",
                        label: "°C · km/h"
                    },
                    {
                        key: "imperial",
                        label: "°F · mph"
                    }
                ]
                onPicked: key => Settings.put("weather.units", key)
            }
        }

        SettingRow {
            title: "Refresh every"
            key: "weather.refresh"
            advanced: true
            last: true

            Stepper {
                value: Settings.shown.weather.refresh
                from: 10
                to: 360
                step: 10
                suffix: " min"
                onStepped: v => Settings.put("weather.refresh", v)
            }
        }
    }
}
