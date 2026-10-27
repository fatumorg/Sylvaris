pragma Singleton

import QtQuick
import SylStack
import "../lib/sky.mjs" as K

Singleton {
    id: root

    readonly property var configured: Config.values.location
    property var zoned: null
    readonly property var location: root.valid(root.configured) ? root.configured : root.zoned
    readonly property string source: root.valid(root.configured) ? "config" : root.zoned !== null ? "timezone" : "none"
    readonly property bool available: root.location !== null
    readonly property real latitude: root.available ? root.location.latitude : 0
    readonly property real longitude: root.available ? root.location.longitude : 0
    property string zone: ""

    readonly property real offset: Demo.enabled && Stack.env("SYLVARIS_SKY_TIME") ? Date.parse(Stack.env("SYLVARIS_SKY_TIME")) - Date.now() : 0
    property real now: Date.now() + root.offset
    readonly property real day: K.dayStart(root.now)
    readonly property var sun: K.sunPosition(root.now, root.latitude, root.longitude)
    readonly property var moon: K.moonPosition(root.now, root.latitude, root.longitude)
    readonly property var illumination: K.moonIllumination(root.now)
    readonly property string phaseName: K.phaseName(root.illumination.phase)
    readonly property string daylight: K.daylight(root.sun.altitude)
    readonly property var sunCurve: K.curve(root.day, root.latitude, root.longitude, "sun", 96)
    readonly property var moonCurve: K.curve(root.day, root.latitude, root.longitude, "moon", 96)
    readonly property var sunTimes: K.crossings(root.sunCurve, K.SUN_HORIZON)
    readonly property var moonTimes: K.crossings(root.moonCurve, K.MOON_HORIZON)
    readonly property real nextFull: K.nextPhase(root.day, 0.5) || 0
    readonly property real nextNew: K.nextPhase(root.day, 0) || 0

    function tick(): void {
        root.now = Date.now() + root.offset;
    }

    function valid(l: var): bool {
        return l !== null && typeof l === "object" && typeof l.latitude === "number" && typeof l.longitude === "number" && Math.abs(l.latitude) <= 90 && Math.abs(l.longitude) <= 180;
    }

    function state(): var {
        return {
            available: root.available,
            source: root.source,
            latitude: root.latitude,
            longitude: root.longitude,
            daylight: root.daylight,
            sun: root.sun,
            moon: root.moon,
            phase: root.phaseName,
            illumination: Math.round(root.illumination.fraction * 100) / 100,
            sunrise: root.sunTimes.rise,
            sunset: root.sunTimes.set,
            moonrise: root.moonTimes.rise,
            moonset: root.moonTimes.set,
            nextFull: root.nextFull,
            nextNew: root.nextNew
        };
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    Process {
        running: true
        command: ["sh", "-c", "if [ -n \"$TZ\" ]; then printf 'zoneinfo/%s' \"${TZ#:}\"; else readlink -f /etc/localtime; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.zone = K.zoneFromPath(text)
        }
    }

    FileView {
        path: root.zone === "" ? "" : "/etc/zoneinfo/zone1970.tab"
        printErrors: false
        onLoaded: root.zoned = K.zoneLocation(text(), root.zone)
        onLoadFailed: fallback.reload()
    }

    FileView {
        id: fallback
        path: root.zone === "" ? "" : "/usr/share/zoneinfo/zone1970.tab"
        preload: false
        printErrors: false
        onLoaded: root.zoned = K.zoneLocation(text(), root.zone)
    }
}
