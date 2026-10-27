pragma Singleton

import QtQuick
import SylStack
import "../lib/keys.mjs" as K
import "../lib/perf.mjs" as P

Singleton {
    id: root

    readonly property var wanted: Settings.values.keybinds
    readonly property bool supported: Compositor.can("keybinds")
    property var applied: ({})
    property var external: ({})
    property bool included: false
    property real quietUntil: 0
    readonly property string configHome: Stack.env("XDG_CONFIG_HOME") || Stack.env("HOME") + "/.config"
    readonly property string file: K.bindsPath(Compositor.name, Compositor.usingLua, root.configHome)
    readonly property string include: K.includeLine(Compositor.name, Compositor.usingLua)
    readonly property string dir: Compositor.name === "hyprland" ? root.configHome + "/hypr" : root.configHome + "/sway"
    readonly property bool lite: P.liteFor(Settings.values.performance, Toggles.customPerformance, [])

    function apply(force: bool): void {
        if (Demo.enabled || !root.supported) {
            root.applied = root.wanted;
            return;
        }
        root.quietUntil = Date.now() + 2000;
        const d = K.diff(force ? {} : root.applied, root.wanted);
        if (!force)
            for (const combo of d.unbind)
                Stack.execDetached(K.unbindArgs(Compositor.name, Compositor.usingLua, combo));
        for (const b of d.bind)
            Stack.execDetached(K.bindArgs(Compositor.name, Compositor.usingLua, b[0], b[1]));
        root.applied = root.wanted;
        root.save();
    }

    function save(): void {
        if (root.file === "")
            return;
        writer.command = ["sh", "-c", "[ -d \"$(dirname \"$1\")\" ] && printf %s \"$2\" > \"$1.part\" && mv -f \"$1.part\" \"$1\"", "sh", root.file, K.bindsFile(Compositor.name, Compositor.usingLua, root.wanted)];
        writer.running = true;
    }

    function refresh(): void {
        if (Demo.enabled || !root.supported)
            return;
        reader.command = Compositor.name === "hyprland" && !Compositor.usingLua ? ["hyprctl", "binds", "-j"] : ["sh", "-c", "find -L \"$1\" -maxdepth 2 -type f ! -name 'sylvaris-keybinds*' -exec cat {} + 2>/dev/null", "sh", root.dir];
        reader.running = true;
        probe.command = ["grep", "-Rqs", "--exclude=sylvaris-keybinds*", "sylvaris-keybinds", root.dir];
        probe.running = true;
    }

    function trim(on: bool): void {
        const args = P.perfArgs(Compositor.name, Compositor.usingLua, on);
        if (Demo.enabled || args === null)
            return;
        root.quietUntil = Date.now() + 2000;
        Stack.execDetached(args);
        if (!on && Compositor.name === "sway")
            rebind.restart();
    }

    onWantedChanged: root.apply(false)
    onLiteChanged: root.trim(root.lite)
    Component.onCompleted: {
        root.apply(false);
        root.refresh();
        if (root.lite)
            root.trim(true);
    }

    Process {
        id: writer
        onExited: root.refresh()
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                let pairs = [];
                try {
                    pairs = Compositor.name === "sway" ? K.parseSwayBinds(text) : Compositor.usingLua ? K.parseLuaBinds(text) : K.parseHyprBinds(JSON.parse(text));
                } catch (e) {
                    pairs = [];
                }
                root.external = K.externalBinds(pairs);
            }
        }
    }

    Process {
        id: probe
        onExited: code => root.included = code === 0
    }

    Timer {
        id: rebind
        interval: 600
        onTriggered: root.apply(true)
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            if (event.name !== "configreloaded" || Date.now() < root.quietUntil)
                return;
            root.apply(true);
            root.refresh();
            if (root.lite)
                root.trim(true);
        }
    }
}
