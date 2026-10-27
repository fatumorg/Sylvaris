pragma Singleton

import QtQuick
import SylStack
import "../lib/displays.mjs" as D

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property bool installed: false
    readonly property bool available: root.demo || root.installed
    property var outputs: []
    property var current: ({})
    property var previous: null
    property int countdown: 0
    property string error: ""
    property bool restored: false
    readonly property string key: D.layoutKey(root.outputs)
    readonly property var saved: Settings.values.displays.layouts[root.key] === undefined ? null : Settings.values.displays.layouts[root.key]

    function sizes(): var {
        const out = {};
        for (const s of Stack.screens)
            out[s.name] = {
                width: Math.round(s.width * s.devicePixelRatio),
                height: Math.round(s.height * s.devicePixelRatio)
            };
        return out;
    }

    function ingest(text: string): void {
        root.outputs = D.parseOutputs(text, root.sizes());
        root.current = D.snapshot(root.outputs);
        if (root.restored)
            return;
        root.restored = true;
        if (root.saved !== null && D.canApply(root.saved) && !D.sameLayout(root.saved, root.current))
            root.run(root.saved);
    }

    function refresh(): void {
        if (root.demo) {
            if (root.outputs.length === 0)
                root.ingest(JSON.stringify(Demo.outputs));
            return;
        }
        if (!root.installed || query.running)
            return;
        query.running = true;
    }

    function restore(): void {
        root.restored = false;
        root.refresh();
    }

    function run(snap: var): void {
        if (root.demo) {
            root.current = snap;
            return;
        }
        applyProc.command = ["wlr-randr"].concat(D.applyArgs(snap));
        applyProc.running = true;
    }

    function apply(snap: var): void {
        if (!D.canApply(snap)) {
            root.error = "At least one display has to stay on";
            return;
        }
        root.previous = root.current;
        root.run(snap);
        root.countdown = 15;
        countdownTimer.restart();
    }

    function keep(): void {
        countdownTimer.stop();
        root.countdown = 0;
        root.previous = null;
    }

    function revert(): void {
        countdownTimer.stop();
        root.countdown = 0;
        if (root.previous !== null)
            root.run(root.previous);
        root.previous = null;
    }

    function save(): void {
        if (D.canApply(root.current))
            Settings.set("displays.layouts." + root.key, root.current);
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v wlr-randr"]
        running: true
        onExited: code => {
            root.installed = code === 0;
            root.refresh();
        }
    }

    Process {
        id: query
        command: ["wlr-randr", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    Process {
        id: applyProc
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: code => {
            root.error = code === 0 ? "" : (applyErr.text.trim() || "wlr-randr could not apply the layout");
            root.refresh();
        }
    }
}
