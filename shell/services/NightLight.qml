pragma Singleton

import QtQuick
import SylStack
import "../lib/night.mjs" as N

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property bool installed: false
    readonly property bool available: root.demo || root.installed
    readonly property bool enabled: Settings.values.nightLight.enabled
    readonly property int temperature: Settings.values.nightLight.temperature
    property string error: ""
    property bool mirrored: false
    property bool shaderOwner: false
    readonly property bool viaShader: !root.demo && root.enabled && root.shaderOwner && root.mirrored && Compositor.name === "hyprland"
    readonly property var tint: root.viaShader ? N.kelvinRgb(root.temperature) : null

    function setEnabled(v: bool): void {
        root.error = "";
        if (v && !root.demo)
            Stack.execDetached(["pkill", "-x", "hyprsunset"]);
        Settings.set("nightLight.enabled", v);
    }

    function refreshMirrors(): void {
        if (Compositor.name !== "hyprland" || root.demo || monitors.running)
            return;
        monitors.running = true;
    }

    Component.onCompleted: root.refreshMirrors()

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            if (event.name.indexOf("monitoradded") === 0 || event.name.indexOf("monitorremoved") === 0 || event.name === "configreloaded")
                root.refreshMirrors();
        }
    }

    Process {
        id: monitors
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.mirrored = N.hasMirror(JSON.parse(text));
                } catch (e) {
                    root.mirrored = false;
                }
            }
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v wlsunset"]
        running: true
        onExited: code => root.installed = code === 0
    }

    Process {
        id: sunset
        command: ["wlsunset", "-T", String(root.temperature + 1), "-t", String(root.temperature)]
        running: !root.demo && root.installed && root.enabled && !root.viaShader
        onExited: code => {
            if (root.enabled && code !== 0)
                root.error = "wlsunset exited with code " + code;
        }
    }
}
