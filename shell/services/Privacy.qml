pragma Singleton

import QtQuick
import SylStack
import "../lib/privacy.mjs" as P

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property bool demoOn: false
    property var cameras: ({
            blocked: 0,
            live: 0,
            denied: 0
        })
    readonly property var sources: {
        const out = [];
        if (root.demo)
            return out;
        for (const n of Pipewire.nodes.values) {
            if (!n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        return out;
    }
    readonly property bool micMuted: root.demo ? root.demoOn : root.sources.length > 0 && root.sources.every(n => n.audio.muted)
    readonly property bool active: root.demo ? root.demoOn : root.micMuted && root.cameras.live === 0

    function set(on: bool): void {
        if (root.demo) {
            root.demoOn = on;
            return;
        }
        for (const n of root.sources)
            n.audio.muted = on;
        root.run(on ? "off" : "on");
    }

    function run(mode: string): void {
        cams.command = P.cameraArgs(mode, "");
        cams.running = true;
    }

    function state(): var {
        return {
            active: root.active,
            micMuted: root.micMuted,
            microphones: root.sources.length,
            cameras: root.cameras
        };
    }

    Component.onCompleted: {
        if (!root.demo)
            root.run("state");
    }

    PwObjectTracker {
        objects: root.sources
    }

    Process {
        id: cams
        stdout: StdioCollector {
            onStreamFinished: root.cameras = P.parseCameras(text)
        }
    }
}
