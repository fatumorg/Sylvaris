pragma Singleton

import QtQuick
import SylStack
import "../lib/eq.mjs" as E

Singleton {
    id: root

    readonly property var cfg: Settings.values.media.eq
    readonly property bool enabled: root.cfg.enabled || root.cfg.spatial
    readonly property string path: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/eq.conf"
    readonly property var node: root.find("sylvaris_eq")
    readonly property var outNode: root.find("sylvaris_eq_out")
    readonly property bool running: root.node !== null
    property string target: ""
    property string error: ""

    function effective(): var {
        const c = Settings.values.media.eq;
        return c.enabled ? c : Object.assign({}, c, {
            bands: E.PRESETS.flat
        });
    }

    function find(name: string): var {
        if (Demo.enabled || !Pipewire.ready)
            return null;
        for (const n of Pipewire.nodes.values) {
            if (n.name === name)
                return n;
        }
        return null;
    }

    function hardwareDefault(): string {
        const s = Pipewire.defaultAudioSink;
        if (s && s.name.indexOf("sylvaris_eq") !== 0)
            return s.name;
        const t = root.outNode !== null && root.outNode.properties ? root.outNode.properties["target.object"] : "";
        return t || root.target;
    }

    function set(patch: var): void {
        const next = Object.assign({}, root.cfg, patch);
        if (patch.bands !== undefined && patch.preset === undefined)
            next.preset = E.presetOf(next.bands);
        if (patch.preset !== undefined && patch.preset !== "custom")
            next.bands = E.PRESETS[patch.preset].slice();
        Settings.set("media.eq", next);
    }

    function setBand(i: int, gain: real): void {
        const bands = root.cfg.bands.slice();
        bands[i] = Math.round(gain * 2) / 2;
        root.set({
            bands: bands
        });
    }

    function write(): void {
        file.setText(E.config(root.effective(), root.target));
    }

    function retarget(name: string): void {
        root.target = name;
        if (!root.enabled)
            return;
        root.write();
        if (root.outNode !== null)
            Stack.execDetached(["pw-metadata", String(root.outNode.id), "target.object", name]);
    }

    function push(): void {
        root.write();
        if (root.node !== null)
            Stack.execDetached(["pw-cli", "set-param", String(root.node.id), "Props", E.paramsText(root.effective())]);
    }

    function start(): void {
        stopLater.stop();
        if (Demo.enabled)
            return;
        if (root.target === "")
            root.target = root.hardwareDefault();
        root.write();
        root.error = "";
        launcher.running = true;
        if (root.node !== null) {
            root.push();
            Pipewire.preferredDefaultAudioSink = root.node;
        }
    }

    function stop(): void {
        const hw = root.find(root.target);
        if (hw !== null)
            Pipewire.preferredDefaultAudioSink = hw;
        stopLater.restart();
    }

    onEnabledChanged: {
        if (root.enabled)
            root.start();
        else
            root.stop();
    }

    onCfgChanged: {
        if (root.enabled && root.running)
            pushLater.restart();
    }

    onNodeChanged: {
        if (root.node !== null && root.enabled)
            Pipewire.preferredDefaultAudioSink = root.node;
    }

    Component.onCompleted: {
        if (root.enabled)
            startLater.start();
    }

    Timer {
        id: startLater
        interval: 1500
        onTriggered: root.start()
    }

    Timer {
        id: pushLater
        interval: 60
        onTriggered: root.push()
    }

    Timer {
        id: stopLater
        interval: 1500
        onTriggered: {
            if (!root.enabled)
                Stack.execDetached(["pkill", "-f", "^pipewire -c " + root.path + "$"]);
        }
    }

    FileView {
        id: file
        path: root.path
        atomicWrites: true
        blockWrites: true
        printErrors: false
    }

    Process {
        id: launcher
        command: ["sh", "-c", "q=$PPID; p=$(pgrep -of \"^pipewire -c $1$\"); if [ -z \"$p\" ]; then setsid pipewire -c \"$1\" >/dev/null 2>\"$1.log\" & p=$!; fi; pgrep -f \"sylvaris-eq-watch [0-9]\" >/dev/null || setsid sh -c 'while kill -0 $1 2>/dev/null && kill -0 $2 2>/dev/null; do sleep 2; done; kill $2 2>/dev/null' sylvaris-eq-watch $q $p >/dev/null 2>&1 & sleep 1; kill -0 $p 2>/dev/null || { tail -n 1 \"$1.log\" >&2; exit 1; }", "sylvaris-eq", root.path]
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
    }

    PwObjectTracker {
        objects: [root.node, root.outNode].filter(n => n !== null)
    }
}
