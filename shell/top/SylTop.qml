import QtQuick
import qs
import SylStack
import qs.services
import "../lib/top.mjs" as T

Scope {
    id: root

    property bool wanted: false
    property var screenInfo: null
    readonly property bool windowed: true
    readonly property string title: "SylTop"
    readonly property var cfg: Settings.values.top
    readonly property real interval: root.cfg.interval
    property string page: "processes"
    property var sample: null
    property var history: ({})
    property var startup: null
    property var services: null
    property var sessions: null
    property var files: null
    property var detail: null
    property string note: ""
    property string sortKey: "cpu"
    property bool desc: true
    property string query: ""
    property var folded: []
    property int selected: -1
    readonly property var procs: root.sample === null ? [] : T.filterProcs(root.sample.procs, root.query)
    readonly property var rows: root.cfg.tree && root.query === "" ? T.tree(root.procs, root.sortKey, root.desc, root.folded) : T.sortProcs(root.procs, root.sortKey, root.desc)
    readonly property var picked: root.sample === null ? null : root.sample.procs.find(p => p.pid === root.selected) || null

    signal opened

    function open(page: string): void {
        if (page !== "") {
            if (!T.PAGES.some(p => p.id === page))
                throw new Error("unknown page: " + page + "; one of " + T.PAGES.map(p => p.id).join(", "));
            root.show(page);
        }
        const fresh = !root.wanted;
        root.wanted = true;
        if (fresh)
            root.opened();
        else
            root.raise();
    }

    function toggleOn(screen: var): void {
        root.screenInfo = screen;
        root.toggle();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open("");
    }

    function close(): void {
        root.wanted = false;
        root.sample = null;
        root.history = {};
        root.startup = null;
        root.services = null;
        root.sessions = null;
        root.files = null;
        root.detail = null;
        root.note = "";
        root.selected = -1;
    }

    function raise(): void {
        const t = ToplevelManager.toplevels.values.find(w => w.title === root.title);
        if (t)
            t.activate();
    }

    function find(text: string): void {
        root.open("processes");
        root.query = text;
    }

    function show(page: string): void {
        root.page = page;
        if (page === "startup")
            root.send({
                cmd: "startup"
            });
        else if (page === "services")
            root.send({
                cmd: "services"
            });
        else if (page === "users")
            root.send({
                cmd: "users"
            });
    }

    function sortBy(key: string): void {
        if (root.sortKey === key)
            root.desc = !root.desc;
        else {
            root.sortKey = key;
            root.desc = !T.COLUMNS.find(c => c.key === key).text;
        }
    }

    function fold(pid: int): void {
        root.folded = root.folded.indexOf(pid) >= 0 ? root.folded.filter(p => p !== pid) : root.folded.concat([pid]);
    }

    function select(pid: int): void {
        root.selected = pid;
        root.files = null;
        root.detail = null;
    }

    function send(msg: var): void {
        if (sampler.running)
            sampler.write(JSON.stringify(msg) + "\n");
    }

    function act(msg: var): void {
        if (Demo.enabled) {
            root.note = "Demo mode: " + msg.cmd + " was not sent";
            return;
        }
        root.note = "";
        root.send(msg);
    }

    function signalTo(pid: int, sig: string): void {
        root.act({
            cmd: "signal",
            pid: pid,
            sig: sig
        });
    }

    function renice(pid: int, nice: int): void {
        root.act({
            cmd: "renice",
            pid: pid,
            nice: nice
        });
    }

    function ionice(pid: int, klass: string): void {
        root.act({
            cmd: "ionice",
            pid: pid,
            class: klass
        });
    }

    function pin(pid: int, cpus: var): void {
        root.act({
            cmd: "affinity",
            pid: pid,
            cpus: cpus
        });
    }

    function openFiles(pid: int): void {
        root.send({
            cmd: "files",
            pid: pid
        });
    }

    function inspect(pid: int): void {
        root.send({
            cmd: "detail",
            pid: pid
        });
    }

    function unit(scope: string, verb: string, name: string): void {
        root.act({
            cmd: "unit",
            scope: scope,
            verb: verb,
            name: name
        });
    }

    function autostart(file: string, on: bool): void {
        root.act({
            cmd: "autostart",
            file: file,
            on: on
        });
    }

    function take(line: string): void {
        let e = null;
        try {
            e = JSON.parse(line);
        } catch (err) {
            return;
        }
        switch (e.event) {
        case "sample":
            root.sample = e;
            root.remember(e);
            break;
        case "startup":
            root.startup = e;
            break;
        case "services":
            root.services = e;
            break;
        case "users":
            root.sessions = e.sessions;
            break;
        case "files":
            root.files = e.pid === root.selected ? e.files : root.files;
            break;
        case "detail":
            root.detail = e.pid === root.selected ? e : root.detail;
            break;
        case "error":
            root.note = e.message;
            break;
        case "done":
            if (e.cmd === "unit")
                root.send({
                    cmd: e.verb === "enable" || e.verb === "disable" ? "startup" : "services"
                });
            break;
        }
    }

    function remember(e: var): void {
        const h = root.history;
        const n = T.HISTORY;
        root.history = {
            cpu: T.push(h.cpu, e.cpu.total, n),
            cores: e.cpu.cores.map((v, i) => T.push(h.cores ? h.cores[i] : [], v, n)),
            mem: T.push(h.mem, e.mem.total > 0 ? e.mem.used / e.mem.total * 100 : 0, n),
            swap: T.push(h.swap, e.mem.swapTotal > 0 ? e.mem.swapUsed / e.mem.swapTotal * 100 : 0, n),
            read: T.push(h.read, e.disk.read, n),
            write: T.push(h.write, e.disk.write, n),
            rx: T.push(h.rx, e.net.rx, n),
            tx: T.push(h.tx, e.net.tx, n),
            gpus: e.gpus.map((g, i) => T.push(h.gpus ? h.gpus[i] : [], g.busy, n))
        };
    }

    function state(): var {
        return {
            open: root.wanted,
            page: root.page,
            running: sampler.running,
            procs: root.sample === null ? 0 : root.sample.procs.length,
            shown: root.rows.length,
            cpu: root.sample === null ? null : root.sample.cpu.total,
            gpus: root.sample === null ? 0 : root.sample.gpus.length,
            tree: root.cfg.tree,
            sort: root.sortKey,
            query: root.query,
            note: root.note
        };
    }

    onIntervalChanged: root.send({
        cmd: "interval",
        seconds: root.interval
    })

    Process {
        id: sampler
        running: root.wanted
        command: ["python3", Qt.resolvedUrl("../helpers/top.py").toString().replace("file://", "")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
        onRunningChanged: {
            if (running) {
                root.send({
                    cmd: "interval",
                    seconds: root.interval
                });
                root.show(root.page);
            }
        }
    }

    LazyLoader {
        active: root.wanted

        TopWindow {
            task: root
        }
    }
}
