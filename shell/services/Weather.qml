pragma Singleton

import QtQuick
import SylStack
import "../lib/weather.mjs" as W

Singleton {
    id: root

    readonly property var cfg: Settings.values.weather
    readonly property bool enabled: root.cfg.enabled && Sky.available
    property var data: null
    property string error: ""
    property real fetched: 0
    readonly property bool available: root.data !== null
    readonly property var now: root.data === null ? null : W.describe(root.data.code, root.data.day)
    readonly property string cachePath: (Stack.env("XDG_CACHE_HOME") || Stack.env("HOME") + "/.cache") + "/sylvaris/weather.json"

    function refresh(): void {
        if (Demo.enabled) {
            root.data = W.parse(root.demoData(), Date.parse("2026-09-24T09:00:00Z"));
            return;
        }
        if (!root.enabled || fetcher.running)
            return;
        fetcher.command = ["sh", "-c", "umask 077; d=$(dirname \"$2\"); mkdir -p \"$d\" && chmod 700 \"$d\" && curl -fsS --max-time 15 \"$1\" -o \"$2.part\" && mv \"$2.part\" \"$2\"", "sylvaris-weather", W.url(Sky.latitude, Sky.longitude, root.cfg.units), root.cachePath];
        fetcher.running = true;
    }

    function ingest(text: string): void {
        try {
            const parsed = W.parse(JSON.parse(text));
            if (parsed !== null) {
                root.data = parsed;
                root.error = "";
            }
        } catch (e) {
            root.error = "Could not read the forecast";
        }
    }

    function state(): var {
        return {
            enabled: root.enabled,
            available: root.available,
            error: root.error,
            now: root.data === null ? null : Object.assign({
                label: W.describe(root.data.code, root.data.day).label
            }, root.data, {
                hours: root.data.hours.length,
                days: root.data.days.length
            })
        };
    }

    function demoData(): var {
        return {
            utc_offset_seconds: 7200,
            current_units: {
                temperature_2m: "°C",
                wind_speed_10m: "km/h"
            },
            current: {
                temperature_2m: 17.6,
                apparent_temperature: 16.2,
                relative_humidity_2m: 64,
                weather_code: 2,
                wind_speed_10m: 11,
                is_day: 1
            },
            hourly: {
                time: [...Array(24).keys()].map(i => "2026-09-24T" + String(i).padStart(2, "0") + ":00"),
                temperature_2m: [...Array(24).keys()].map(i => 12 + 7 * Math.sin((i - 8) / 24 * Math.PI * 2)),
                weather_code: [...Array(24).keys()].map(i => i < 13 ? 2 : i < 17 ? 61 : i < 20 ? 3 : 0),
                precipitation_probability: [...Array(24).keys()].map(i => i >= 13 && i < 17 ? 65 : 5),
                is_day: [...Array(24).keys()].map(i => i >= 7 && i < 19 ? 1 : 0)
            },
            daily: {
                time: ["2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27", "2026-09-28", "2026-09-29"],
                weather_code: [61, 0, 2, 3, 95, 1],
                temperature_2m_max: [19, 22, 21, 17, 15, 18],
                temperature_2m_min: [11, 10, 12, 11, 9, 8],
                precipitation_probability_max: [70, 0, 10, 30, 80, 5]
            }
        };
    }

    onEnabledChanged: root.refresh()
    Component.onCompleted: {
        cache.reload();
        root.refresh();
    }

    Connections {
        target: Settings
        function onValuesChanged() {
            if (root.data !== null && Settings.values.weather.units !== root.lastUnits) {
                root.lastUnits = Settings.values.weather.units;
                root.refresh();
            }
        }
    }

    property string lastUnits: Settings.values.weather.units

    Timer {
        interval: root.cfg.refresh * 60000
        running: root.enabled && !Demo.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    FileView {
        id: cache
        path: root.cachePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.ingest(text())
    }

    Process {
        id: fetcher
        onExited: code => {
            if (code === 0)
                root.fetched = Date.now();
            else
                root.error = root.data === null ? "No forecast yet, check the connection" : "Showing the last forecast";
        }
    }
}
