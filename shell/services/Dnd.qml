pragma Singleton

import QtQuick
import SylStack

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    readonly property bool own: Notifications.enabled
    property string external: ""
    property bool externalEnabled: false
    readonly property string tool: root.own ? "sylvaris" : root.external
    readonly property bool enabled: root.own ? Notifications.dnd : root.externalEnabled
    readonly property bool available: root.demo || root.tool !== ""

    function refresh(): void {
        if (root.own || root.demo || root.external === "" || query.running)
            return;
        query.command = root.external === "swaync" ? ["swaync-client", "-D"] : ["makoctl", "mode"];
        query.running = true;
    }

    function setEnabled(v: bool): void {
        if (root.own) {
            Notifications.setDnd(v);
            return;
        }
        if (!root.demo) {
            if (root.external === "swaync")
                Stack.execDetached(["swaync-client", v ? "-dn" : "-df"]);
            else if (root.external === "mako")
                Stack.execDetached(["makoctl", "mode", v ? "-a" : "-r", "do-not-disturb"]);
        }
        root.externalEnabled = v;
    }

    Process {
        running: !root.own
        command: ["sh", "-c", "if command -v swaync-client >/dev/null; then echo swaync; elif command -v makoctl >/dev/null; then echo mako; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.external = text.trim();
                root.refresh();
            }
        }
    }

    Process {
        id: query
        stdout: StdioCollector {
            onStreamFinished: root.externalEnabled = root.external === "swaync" ? text.trim() === "true" : text.split("\n").indexOf("do-not-disturb") >= 0
        }
    }
}
