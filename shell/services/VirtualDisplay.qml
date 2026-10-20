pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/virtual.mjs" as V
import "../lib/wm.mjs" as W

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    readonly property string name: V.NAME
    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/wayvnc/config"
    property bool installed: false
    readonly property bool supported: root.demo || Compositor.can("virtualDisplay")
    readonly property bool available: root.supported && (root.demo || (root.installed && Displays.available))
    readonly property int width: Settings.values.displays.virtual.width
    readonly property int height: Settings.values.displays.virtual.height
    property bool demoActive: false
    readonly property bool active: root.demo ? root.demoActive : server.running
    readonly property bool busy: clear.running || (server.running && !root.ready)
    property bool ready: false
    property bool stopping: false
    property var addresses: []
    property var vnc: root.demo ? ({
            username: "sylvaris",
            password: "demo",
            port: 5900
        }) : V.parseVnc("")
    property string error: ""
    property bool resumed: false
    readonly property bool resume: !root.resumed && (root.installed || root.demo) && root.available && Settings.values.displays.virtual.enabled

    onResumeChanged: {
        if (!root.resume)
            return;
        root.resumed = true;
        root.start();
    }

    readonly property string script: "n=$1; m=$2; sc=$3; pos=$4; d=$(dirname \"$5\"); if [ ! -f \"$5\" ]; then mkdir -p \"$d\" && (umask 077 && openssl genrsa -traditional -out \"$d/rsa_key.pem\" 2048 2>/dev/null && printf '%s\\n' use_relative_paths=true address=0.0.0.0 enable_auth=true username=sylvaris \"password=$(openssl rand -hex 8)\" rsa_private_key_file=rsa_key.pem > \"$5\") || { echo 'Could not create the wayvnc config' >&2; exit 1; }; fi; k=\"${XDG_RUNTIME_DIR:-/tmp}/sylvaris-wayvnc.sock\"; wayvncctl -S \"$k\" wayvnc-exit >/dev/null 2>&1; i=0; while [ -e \"$k\" ] && [ $i -lt 25 ]; do i=$((i + 1)); sleep 0.2; done; shift 5; \"$@\" >/dev/null || { echo 'The compositor could not create the virtual display' >&2; exit 1; }; i=0; until wlr-randr --output \"$n\" --custom-mode \"$m\" --scale \"$sc\" --pos \"$pos\" 2>/dev/null; do i=$((i + 1)); [ $i -lt 25 ] || { echo 'The virtual display did not come up' >&2; exit 1; }; sleep 0.2; done; echo ready; exec wayvnc -S \"$k\" -o \"$n\" -f 60"

    function mode(w: int, h: int): string {
        return w + "x" + h + "@60.000Hz";
    }

    function shown(): var {
        const out = {};
        for (const sc of Quickshell.screens) {
            if (Displays.current[sc.name] !== undefined)
                out[sc.name] = Displays.current[sc.name];
        }
        return out;
    }

    function start(): void {
        Settings.set("displays.virtual.enabled", true);
        if (root.demo) {
            root.demoActive = true;
            root.addresses = ["192.168.0.20"];
            const pos = V.rightOf(root.shown(), root.name);
            Displays.ingest(JSON.stringify(Demo.outputs.concat([{
                    name: root.name,
                    enabled: true,
                    position: pos,
                    scale: 2,
                    modes: [{
                            width: root.width,
                            height: root.height,
                            refresh: 60,
                            current: true
                        }]
                }])));
            return;
        }
        if (!root.available || root.active || root.busy)
            return;
        root.error = "";
        root.stopping = false;
        clear.launch = true;
        clear.command = W.virtualOutput(Compositor.name, "remove", root.name);
        clear.running = true;
    }

    function launch(): void {
        const pos = V.rightOf(root.shown(), root.name);
        server.command = ["sh", "-c", root.script, "sylvaris", root.name, root.mode(root.width, root.height), root.width >= 2200 ? "2" : "1", pos.x + "," + pos.y, root.configFile].concat(W.virtualOutput(Compositor.name, "create", root.name));
        server.running = true;
    }

    function stop(): void {
        Settings.set("displays.virtual.enabled", false);
        if (root.demo) {
            root.demoActive = false;
            Displays.ingest(JSON.stringify(Demo.outputs));
            return;
        }
        root.stopping = true;
        server.running = false;
    }

    function setSize(w: int, h: int): void {
        Settings.set("displays.virtual.width", w);
        Settings.set("displays.virtual.height", h);
        const now = Displays.current[root.name];
        if (root.demo || !root.active || now === undefined || !now.enabled)
            return;
        const next = JSON.parse(JSON.stringify(Displays.current));
        next[root.name] = Object.assign({}, now, {
            width: w,
            height: h,
            refresh: 60,
            custom: true
        });
        Displays.run(next);
    }

    function refresh(): void {
        if (root.demo || addressQuery.running)
            return;
        addressQuery.running = true;
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v wayvnc && command -v openssl && command -v wlr-randr"]
        running: true
        onExited: code => root.installed = code === 0
    }

    Process {
        id: clear
        property bool launch: false
        onExited: {
            if (!clear.launch)
                return;
            clear.launch = false;
            root.launch();
        }
    }

    Process {
        id: server
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "ready")
                    return;
                root.ready = true;
                root.refresh();
                vncFile.reload();
                Displays.restore();
            }
        }
        stderr: StdioCollector {
            id: serverErr
        }
        onExited: code => {
            root.ready = false;
            if (!root.stopping && code !== 0)
                root.error = serverErr.text.trim().split("\n").pop() || "wayvnc stopped";
            root.stopping = false;
            Quickshell.execDetached(W.virtualOutput(Compositor.name, "remove", root.name));
            refreshLater.restart();
        }
    }

    Timer {
        id: refreshLater
        interval: 400
        onTriggered: Displays.refresh()
    }

    Process {
        id: addressQuery
        command: ["ip", "-4", "-o", "addr", "show", "scope", "global"]
        stdout: StdioCollector {
            onStreamFinished: root.addresses = V.parseAddresses(text)
        }
    }

    FileView {
        id: vncFile
        path: root.demo ? "" : root.configFile
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.vnc = V.parseVnc(text())
    }
}
