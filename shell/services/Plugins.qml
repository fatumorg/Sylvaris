pragma Singleton

import QtQuick
import SylStack
import "../lib/plugins.mjs" as P

Singleton {
    id: root

    readonly property string dir: (Stack.env("XDG_CONFIG_HOME") || Stack.env("HOME") + "/.config") + "/sylvaris/plugins"
    readonly property var cfg: Settings.values.plugins
    property var list: P.withBuiltins([])
    property string problem: ""
    property var pending: null
    readonly property string staging: root.dir + "/.staging"
    property bool fetching: false
    property bool busy: root.fetching || mover.running

    function refresh(): void {
        scan.running = false;
        scan.running = true;
    }

    function byId(id: string): var {
        return root.list.find(p => p.id === id && p.ok) || null;
    }

    function isEnabled(id: string): bool {
        return root.cfg.enabled[id] === true;
    }

    function active(kind: string): var {
        return root.list.filter(p => p.ok && p.manifest.kind === kind && root.isEnabled(p.id));
    }

    function url(p: var): string {
        return "file://" + p.dir + "/" + p.manifest.entry;
    }

    function api(id: string): var {
        return {
            id: id,
            config: root.cfg.config[id] || {},
            set: (key, value) => Settings.set("plugins.config." + id + "." + key, value),
            run: words => Ipc.run(words)
        };
    }

    function setEnabled(id: string, on: bool): void {
        const next = Object.assign({}, root.cfg.enabled);
        next[id] = on;
        Settings.set("plugins.enabled", next);
    }

    function create(id: string, kind: string): void {
        if (!P.isPluginModule("plugin:" + id))
            throw new Error("a plugin id is lowercase letters, digits and dashes");
        if (P.KINDS.indexOf(kind) < 0)
            throw new Error("kind must be one of " + P.KINDS.join(", "));
        if (root.list.some(p => p.id === id))
            throw new Error(id + " already exists");
        const files = P.skeleton(id, kind);
        writer.command = ["sh", "-c", "mkdir -p \"$0\" && printf '%s' \"$1\" > \"$0/plugin.json\" && printf '%s' \"$2\" > \"$0/Plugin.qml\"", root.dir + "/" + id, files["plugin.json"], files["Plugin.qml"]];
        writer.running = true;
    }

    function install(source: string): string {
        const g = P.parseGitSource(source);
        if (g === null)
            throw new Error("give an https git address whose last part is the plugin id, like https://github.com/you/uptime");
        if (root.list.some(p => p.id === g.id))
            throw new Error(g.id + " is already installed");
        if (root.busy)
            throw new Error("another install is still running");
        root.discard();
        root.problem = "";
        root.fetching = true;
        installer.target = g;
        installer.command = ["sh", "-c", "rm -rf \"$1\" && mkdir -p \"$(dirname \"$1\")\" && GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true timeout 120 git clone -q --depth 1 -- \"$0\" \"$1\" 2>&1 && git -C \"$1\" rev-parse HEAD", g.url, root.staging + "/" + g.id];
        installer.running = true;
        return "fetching " + g.id + "; nothing is installed until you confirm";
    }

    function pendingText(): string {
        if (root.fetching)
            return "fetching";
        if (root.problem !== "")
            throw new Error(root.problem);
        return P.pendingSummary(root.pending);
    }

    function confirm(): void {
        if (root.pending === null)
            throw new Error("nothing is waiting to be installed; start with: sylvaris plugins install <https git address>");
        if (root.list.some(p => p.id === root.pending.id))
            throw new Error(root.pending.id + " is already installed");
        mover.command = ["sh", "-c", "[ ! -e \"$1\" ] && mv -- \"$0\" \"$1\"", root.staging + "/" + root.pending.id, root.dir + "/" + root.pending.id];
        root.pending = null;
        mover.running = true;
    }

    function discard(): void {
        if (root.pending === null)
            return;
        writer.command = ["rm", "-rf", "--", root.staging + "/" + root.pending.id];
        root.pending = null;
        writer.running = true;
    }

    function remove(id: string): void {
        if (!P.isPluginModule("plugin:" + id) || !root.list.some(p => p.id === id))
            throw new Error("no plugin called " + id);
        if (P.BUILTIN.some(b => b.id === id))
            throw new Error(id + " comes with Sylvaris and cannot be removed; turn it off with: sylvaris plugins disable " + id);
        const next = Object.assign({}, root.cfg.enabled);
        delete next[id];
        Settings.set("plugins.enabled", next);
        writer.command = ["rm", "-rf", "--", root.dir + "/" + id];
        writer.running = true;
    }

    function state(): var {
        return {
            dir: root.dir,
            problem: root.problem,
            pending: root.pending === null ? null : Object.assign({
                warning: P.INSTALL_WARNING
            }, root.pending),
            plugins: root.list.map(p => ({
                        id: p.id,
                        ok: p.ok,
                        error: p.error,
                        kind: p.ok ? p.manifest.kind : "",
                        builtin: p.builtin === true,
                        enabled: root.isEnabled(p.id)
                    }))
        };
    }

    Component.onCompleted: root.refresh()

    Process {
        id: scan
        command: ["sh", "-c", "for d in \"$0\"/*/; do [ -d \"$d\" ] || continue; printf '@@%s\\n' \"$d\"; cat \"$d/plugin.json\" 2>/dev/null; echo; done", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.list = P.withBuiltins(P.parseScan(text))
        }
    }

    Process {
        id: writer
        onExited: root.refresh()
    }

    Process {
        id: installer
        property var target: null
        stdout: StdioCollector {
            onStreamFinished: {
                root.fetching = false;
                const lines = text.trim().split("\n");
                const commit = P.readCommit(lines[lines.length - 1]);
                if (commit !== "") {
                    root.pending = Object.assign({
                        commit: commit
                    }, installer.target);
                    root.problem = "";
                } else {
                    root.problem = lines[lines.length - 1] || "git clone failed or took longer than two minutes";
                }
            }
        }
    }

    Process {
        id: mover
        onExited: code => {
            if (code !== 0)
                root.problem = "could not move the plugin into place; it may already exist in " + root.dir;
            root.refresh();
        }
    }
}
