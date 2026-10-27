pragma Singleton

import QtQuick
import SylStack
import "../lib/sync.mjs" as S

Singleton {
    id: root

    readonly property var cfg: Settings.values.sync
    readonly property string helper: Qt.resolvedUrl("../helpers/sync.py").toString().replace("file://", "")
    readonly property string home: Stack.env("HOME")
    readonly property string configHome: Stack.env("XDG_CONFIG_HOME") || root.home + "/.config"
    readonly property var colors: Theme.theme.colors
    property var results: []
    property real last: 0

    function apply(): void {
        if (!root.cfg.enabled)
            return;
        run.ops = JSON.stringify(S.plan(S.palette(root.colors), root.cfg.targets, root.configHome, root.home));
        if (Demo.enabled) {
            root.results = JSON.parse(run.ops).filter(o => o.path).map(o => ({
                        path: o.path,
                        target: o.target,
                        status: "written"
                    }));
            root.last = Date.now();
            return;
        }
        run.running = false;
        run.running = true;
    }

    function state(): var {
        return {
            enabled: root.cfg.enabled,
            targets: root.cfg.targets,
            last: root.last,
            results: root.results
        };
    }

    onColorsChanged: later.restart()
    onCfgChanged: later.restart()

    Timer {
        id: later
        interval: 400
        onTriggered: root.apply()
    }

    Process {
        id: run
        property string ops: "[]"
        command: ["python3", root.helper]
        stdinEnabled: true
        onStarted: {
            write(run.ops);
            stdinEnabled = false;
        }
        onExited: stdinEnabled = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.results = JSON.parse(text);
                } catch (e) {
                    root.results = [];
                }
                root.last = Date.now();
            }
        }
    }
}
