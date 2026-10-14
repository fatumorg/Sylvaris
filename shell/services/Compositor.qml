pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Wayland
import "../lib/screens.mjs" as Screens
import "../lib/wm.mjs" as W

Singleton {
    id: root

    readonly property string name: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : Quickshell.env("NIRI_SOCKET") ? "niri" : Quickshell.env("SWAYSOCK") ? "sway" : "unknown"
    property string niriFocused: ""
    property var pending: []
    property var niriState: ({
            workspaces: [],
            windows: []
        })
    readonly property bool usingLua: root.name === "hyprland" && Hyprland.usingLua
    readonly property var workspaces: root.name === "hyprland" ? root.hyprWorkspaces() : root.name === "sway" ? root.swayWorkspaces() : root.name === "niri" ? W.niriWorkspaces(root.niriState) : []
    readonly property var windows: Demo.enabled ? Demo.windows : ToplevelManager.toplevels.values.map(t => ({
                appId: W.appOf(t.appId, t.title),
                title: t.title,
                activated: t.activated,
                minimized: t.minimized,
                fullscreen: t.fullscreen,
                handle: t
            }))
    readonly property var activeWindow: {
        for (const w of root.windows) {
            if (w.activated)
                return w;
        }
        return null;
    }

    function hyprWorkspaces(): var {
        return Hyprland.workspaces.values.filter(w => w.id > 0).map(w => {
            const live = w.toplevels.values.filter(t => t.wayland);
            return {
                id: String(w.id),
                index: w.id,
                name: w.name,
                output: w.monitor ? w.monitor.name : "",
                active: w.active,
                focused: w.focused,
                urgent: w.urgent,
                windows: live.length,
                apps: live.map(t => W.appOf(t.wayland.appId, t.wayland.title))
            };
        }).sort(W.order);
    }

    function swayWorkspaces(): var {
        return I3.workspaces.values.map(w => ({
                    id: String(w.id),
                    index: w.number > 0 ? w.number : 0,
                    name: w.name,
                    output: w.monitor ? w.monitor.name : "",
                    active: w.active,
                    focused: w.focused,
                    urgent: w.urgent,
                    windows: -1,
                    apps: []
                })).sort(W.order);
    }

    function run(verb: string, args: var): void {
        const t = W.translate(root.name, root.usingLua, verb, args);
        if (t.command === null)
            throw new Error(verb + " is not available on " + root.name);
        if (t.via === "hyprland")
            Hyprland.dispatch(t.command);
        else if (t.via === "i3")
            I3.dispatch(t.command);
        else
            Quickshell.execDetached(t.command);
    }

    function focusWorkspace(ws: var): void {
        if (ws.focused)
            return;
        if (root.name === "niri")
            Quickshell.execDetached(["sh", "-c", "niri msg action focus-monitor \"$1\" && niri msg action focus-workspace \"$2\"", "sylvaris", ws.output, String(ws.index)]);
        else
            root.run("workspace", [String(ws.index)]);
    }

    function activate(w: var): void {
        if (w && w.handle)
            w.handle.activate();
    }

    function addressOf(handle: var): string {
        if (root.name !== "hyprland" || handle === null)
            return "";
        const t = Hyprland.toplevels.values.find(x => x.wayland === handle);
        return t ? t.address : "";
    }

    function minimize(w: var): void {
        if (!w || !w.handle || Demo.enabled)
            return;
        try {
            root.run("minimize", []);
        } catch (e) {
            w.handle.minimized = true;
        }
    }

    function restore(w: var): void {
        if (!w || !w.handle || Demo.enabled)
            return;
        const addr = root.addressOf(w.handle);
        const here = root.workspaces.find(x => x.focused);
        try {
            if (root.name === "hyprland") {
                root.run("restore", [addr, String(here ? here.index : 1)]);
                root.run("focus-window", [addr]);
            } else {
                root.run("restore", []);
            }
        } catch (e) {
            w.handle.minimized = false;
            w.handle.activate();
        }
    }

    function closeWindow(w: var): void {
        if (w && w.handle)
            w.handle.close();
    }

    function can(capability: string): bool {
        return W.can(root.name, capability);
    }

    function state(): var {
        return {
            name: root.name,
            usingLua: root.usingLua,
            focused: root.focusedName(),
            screens: root.screenNames(),
            workspaces: root.workspaces,
            windows: root.windows.map(w => ({
                        appId: w.appId,
                        title: w.title,
                        activated: w.activated
                    })),
            active: root.activeWindow === null ? null : {
                appId: root.activeWindow.appId,
                title: root.activeWindow.title
            }
        };
    }

    function focusedName(): string {
        if (root.name === "hyprland")
            return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        if (root.name === "sway")
            return I3.focusedMonitor ? I3.focusedMonitor.name : "";
        if (root.name === "niri")
            return root.niriFocused;
        return "";
    }

    function screenNames(): var {
        const out = [];
        for (const s of Quickshell.screens)
            out.push(s.name);
        return out;
    }

    function screenFor(name: string): var {
        const i = Screens.pickScreen(root.screenNames(), name);
        return i < 0 ? null : Quickshell.screens[i];
    }

    function flush(): void {
        const callbacks = root.pending;
        root.pending = [];
        for (const cb of callbacks)
            cb();
    }

    function refresh(callback: var): void {
        if (root.name === "unknown" || (root.name !== "niri" && root.focusedName() !== "")) {
            callback();
            return;
        }
        root.pending = root.pending.concat([callback]);
        timeout.restart();
        if (root.name === "niri" && !niriQuery.running)
            niriQuery.running = true;
    }

    Component.onCompleted: root.focusedName()

    Timer {
        id: timeout
        interval: 300
        onTriggered: root.flush()
    }

    Connections {
        target: root.name === "hyprland" ? Hyprland : root.name === "sway" ? I3 : null

        function onFocusedMonitorChanged() {
            if (root.focusedName() === "")
                return;
            timeout.stop();
            root.flush();
        }
    }

    property bool niriStreamUp: true
    property int niriStreamRetries: 0

    Timer {
        id: niriStreamAgain
        interval: Math.min(60000, 2000 * Math.pow(2, root.niriStreamRetries))
        onTriggered: {
            root.niriStreamRetries++;
            root.niriStreamUp = true;
        }
    }

    Process {
        running: root.name === "niri" && root.niriStreamUp
        command: ["niri", "msg", "--json", "event-stream"]
        onExited: {
            root.niriStreamUp = false;
            niriStreamAgain.restart();
        }
        stdout: SplitParser {
            onRead: line => {
                root.niriStreamRetries = 0;
                try {
                    const next = W.niriReduce(root.niriState, JSON.parse(line));
                    if (next !== root.niriState)
                        root.niriState = next;
                } catch (e) {
                    console.warn("sylvaris: could not read a niri event: " + e);
                }
            }
        }
    }

    Process {
        id: niriQuery
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriFocused = JSON.parse(text).name;
                } catch (e) {
                    root.niriFocused = "";
                }
                timeout.stop();
                root.flush();
            }
        }
    }
}
