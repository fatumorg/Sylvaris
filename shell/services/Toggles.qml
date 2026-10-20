pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/icons.mjs" as Icons
import "../lib/perf.mjs" as P

Singleton {
    id: root

    readonly property var defs: Config.values.toggles
    property var status: ({})
    readonly property bool ownPerformance: root.defs.some(d => d.id === "performance")
    readonly property bool customPerformance: root.ownPerformance && Settings.values.toggleState.performance === true
    readonly property bool lite: P.liteFor(Settings.values.performance, root.customPerformance, Compositor.windows)
    readonly property var items: (root.ownPerformance ? [] : [
            {
                id: "performance",
                label: "Performance",
                icon: Icons.GLYPHS.performance,
                on: Settings.values.performance === "on"
            }
        ]).concat(root.defs.map(d => ({
                    id: d.id,
                    label: d.label,
                    icon: d.icon,
                    on: root.stateOf(d)
                })))

    function stateOf(d: var): bool {
        if (d.status !== "" && root.status[d.id] !== undefined)
            return root.status[d.id];
        return Settings.values.toggleState[d.id] === true;
    }

    function set(id: string, on: bool): void {
        if (id === "performance" && !root.ownPerformance) {
            Settings.set("performance", on ? "on" : "auto");
            return;
        }
        let def = null;
        for (const d of root.defs) {
            if (d.id === id)
                def = d;
        }
        if (def === null)
            return;
        const cmd = on ? def.on : def.off;
        if (cmd !== "" && !Demo.enabled)
            Quickshell.execDetached(["sh", "-c", cmd]);
        Settings.set("toggleState." + id, on);
        if (def.status !== "") {
            const next = Object.assign({}, root.status);
            next[id] = on;
            root.status = next;
        }
    }

    function refresh(): void {
        const lines = root.defs.filter(d => d.status !== "").map(d => "(" + d.status + ") >/dev/null 2>&1; echo \"" + d.id + ":$?\"");
        if (lines.length === 0 || statusProc.running)
            return;
        statusProc.command = ["sh", "-c", lines.join("\n")];
        statusProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    const i = line.lastIndexOf(":");
                    if (i > 0)
                        next[line.slice(0, i)] = line.slice(i + 1) === "0";
                }
                root.status = next;
            }
        }
    }
}
