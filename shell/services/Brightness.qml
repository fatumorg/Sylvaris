pragma Singleton

import QtQuick
import SylStack
import "../lib/displays.mjs" as D

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property var targets: ({})
    property var levels: ({})
    property var pending: ({})
    property string error: ""
    readonly property var names: Displays.outputs.filter(o => o.enabled).map(o => o.name)
    readonly property bool available: Object.keys(root.targets).length > 0

    function has(output: string): bool {
        return root.targets[output] !== undefined;
    }

    function level(output: string): real {
        const v = root.levels[output];
        return v === undefined ? -1 : v;
    }

    function refresh(): void {
        if (root.demo) {
            root.targets = D.brightnessTargets(root.names, [{ output: "DP-1", bus: "1" }, { output: "DP-2", bus: "2" }], []);
            if (Object.keys(root.levels).length === 0)
                root.levels = { "DP-1": 0.6, "DP-2": 0.8 };
            return;
        }
        if (!probe.running)
            probe.running = true;
    }

    function ingest(text: string): void {
        const parts = text.split("\n---\n");
        root.targets = D.brightnessTargets(root.names, D.parseDdc(parts[1] || ""), D.parseBacklight(parts[0] || ""));
        const next = {};
        const buses = [];
        for (const name of Object.keys(root.targets)) {
            const t = root.targets[name];
            if (t.kind === "backlight")
                next[name] = t.level;
            else
                buses.push(t.id);
        }
        root.levels = Object.assign({}, root.levels, next);
        if (buses.length > 0 && !reader.running) {
            reader.command = ["sh", "-c", "for b in \"$@\"; do echo \"bus $b\"; ddcutil getvcp 10 --brief --bus \"$b\"; done", "sh"].concat(buses);
            reader.running = true;
        }
    }

    function readVcp(text: string): void {
        const vcp = D.parseVcp(text);
        const next = Object.assign({}, root.levels);
        for (const name of Object.keys(root.targets)) {
            const t = root.targets[name];
            if (t.kind === "ddc" && vcp[t.id] !== undefined && root.pending[name] === undefined)
                next[name] = vcp[t.id];
        }
        root.levels = next;
    }

    function set(output: string, value: real): bool {
        if (!root.has(output))
            return false;
        const v = Math.max(0, Math.min(1, value));
        const next = Object.assign({}, root.levels);
        next[output] = v;
        root.levels = next;
        if (root.demo)
            return true;
        const p = Object.assign({}, root.pending);
        p[output] = v;
        root.pending = p;
        root.pump();
        return true;
    }

    function step(output: string, arg: string): real {
        const name = output !== "" ? output : Object.keys(root.targets).sort()[0];
        if (name === undefined || !root.has(name))
            throw new Error("no display with adjustable brightness" + (output !== "" ? ": " + output : ""));
        const v = D.stepLevel(Math.max(0, root.level(name)), arg);
        if (v === null)
            throw new Error("usage: brightness set <0-100|+N|-N> [output]");
        root.set(name, v);
        return Math.round(v * 100);
    }

    function stepAll(arg: string): var {
        const out = {};
        for (const name of Object.keys(root.targets).sort())
            out[name] = root.step(name, arg);
        return out;
    }

    function pump(): void {
        if (writer.running)
            return;
        const names = Object.keys(root.pending);
        if (names.length === 0)
            return;
        const name = names[0];
        const p = Object.assign({}, root.pending);
        const v = p[name];
        delete p[name];
        root.pending = p;
        if (!root.has(name)) {
            root.pump();
            return;
        }
        writer.command = D.brightnessArgs(root.targets[name], v);
        writer.running = true;
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v brightnessctl >/dev/null && brightnessctl -l -m -c backlight 2>/dev/null; echo; echo ---; command -v ddcutil >/dev/null && ddcutil detect --brief 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: root.readVcp(text)
        }
    }

    Process {
        id: writer
        stderr: StdioCollector {
            id: writeErr
        }
        onExited: code => {
            root.error = code === 0 ? "" : (writeErr.text.trim() || "could not change the brightness");
            pumpLater.restart();
        }
    }

    Timer {
        id: pumpLater
        interval: 40
        onTriggered: root.pump()
    }

    Connections {
        target: Displays

        function onKeyChanged(): void {
            root.refresh();
        }
    }
}
