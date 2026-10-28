pragma Singleton

import QtQuick
import SylStack
import qs.services
import "../../lib/temp.mjs" as T

Singleton {
    id: root

    readonly property var cfg: Settings.values.temp
    readonly property bool enabled: Settings.values.plugins.enabled.temp === true
    property var consumers: ({})
    readonly property bool wanted: root.enabled && Object.keys(root.consumers).some(k => root.consumers[k] === true)
    property bool checked: false
    property bool available: false
    property bool legacy: false
    property string error: ""
    property var sensors: []
    property var history: ({})
    property var peaks: ({})
    property var alertState: ({})
    property int failures: 0
    property bool restarting: false
    readonly property real interval: root.cfg.interval
    readonly property var shown: T.picked(root.sensors, root.cfg.pinned)
    readonly property var top: T.hottest(root.shown)

    function want(consumer: string, on: bool): void {
        if ((root.consumers[consumer] === true) === on)
            return;
        const next = Object.assign({}, root.consumers);
        next[consumer] = on;
        root.consumers = next;
    }

    function take(list: var): void {
        root.sensors = list;
        root.failures = 0;
        if (!root.legacy)
            root.error = "";
        root.history = T.pushHistory(root.history, list);
        root.peaks = T.peaks(root.peaks, list);
        if (!root.cfg.alerts || Demo.enabled)
            return;
        const a = T.alerts(root.alertState, list, Date.now(), root.cfg.cooldown);
        root.alertState = a.state;
        for (const s of a.fire)
            Stack.execDetached(["notify-send", "-a", "SylTemp", "-u", "critical", "-i", "dialog-warning", T.short(s) + " is running hot", (s.device || s.group) + " reached " + Math.round(s.value) + "°, its limit is " + T.limits(s)[1] + "°"]);
    }

    function tone(s: var): color {
        const l = s === null || s === undefined ? "none" : T.level(s);
        return l === "hot" ? Theme.danger : l === "warm" ? Qt.tint(Theme.accent, Qt.alpha(Theme.danger, 0.55)) : l === "cool" ? Theme.accent : Theme.textDim;
    }

    function pin(id: string): void {
        const list = root.cfg.pinned.slice();
        const at = list.indexOf(id);
        if (at >= 0)
            list.splice(at, 1);
        else
            list.push(id);
        Settings.set("temp.pinned", list);
    }

    function sync(): void {
        if (root.wanted && !root.checked && !checker.running)
            checker.running = true;
        stream.running = root.wanted && root.available && !root.legacy && !retry.running;
    }

    function state(): var {
        return {
            available: root.available,
            legacy: root.legacy,
            running: stream.running || poll.running,
            wanted: root.wanted,
            readers: Object.keys(root.consumers).filter(k => root.consumers[k] === true).length,
            error: root.error,
            sensors: root.shown.map(s => ({
                        id: T.sensorId(s),
                        value: s.value,
                        unit: s.unit,
                        level: T.level(s)
                    }))
        };
    }

    onWantedChanged: root.sync()
    onIntervalChanged: {
        if (!stream.running)
            return;
        root.restarting = true;
        stream.running = false;
    }

    Process {
        id: checker
        command: ["sh", "-c", "if command -v tempinfo >/dev/null; then tempinfo --version; else echo missing; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checked = true;
                root.available = text.trim() !== "missing" && text.trim() !== "";
                root.legacy = root.available && !T.streams(text);
                root.error = !root.available ? "TempInfoCLI is not installed; get it from github.com/fatumorg/TempInfoCLI" : root.legacy ? "Update TempInfoCLI to 0.3 for live readings" : "";
                root.sync();
            }
        }
    }

    Process {
        id: stream
        command: ["tempinfo", "--stream", "--interval", String(root.interval)]
        stdout: SplitParser {
            onRead: line => {
                const r = T.parseLine(line);
                if (r !== null)
                    root.take(r.sensors);
            }
        }
        onExited: code => {
            if (root.restarting) {
                root.restarting = false;
                root.sync();
                return;
            }
            if (!root.wanted)
                return;
            root.error = "TempInfoCLI stopped with exit code " + code + "; trying again";
            retry.interval = T.backoff(root.failures);
            root.failures += 1;
            retry.restart();
        }
    }

    Timer {
        id: retry
        onTriggered: root.sync()
    }

    Timer {
        interval: Math.max(5000, root.cfg.interval * 1000)
        running: root.wanted && root.available && root.legacy
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll
        command: ["tempinfo", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = T.parseLegacy(text);
                if (list !== null)
                    root.take(list);
            }
        }
    }
}
