import QtQuick
import SylStack
import "lib/doctor.mjs" as D
import "lib/version.mjs" as V

ShellRoot {
    id: root

    readonly property string dir: (Stack.env("XDG_CONFIG_HOME") || Stack.env("HOME") + "/.config") + "/sylvaris"
    readonly property string out: Stack.env("SYLVARIS_DOCTOR_OUT") || ""
    property var files: ({})
    property var facts: null

    function arrive(name: string, text: var): void {
        const next = Object.assign({}, root.files);
        next[name] = text;
        root.files = next;
        root.finish();
    }

    function finish(): void {
        if (root.facts === null || !("config" in root.files) || !("settings" in root.files) || writer.running)
            return;
        const text = D.report(Object.assign({
            version: V.VERSION,
            fonts: Qt.fontFamilies(),
            config: {
                path: root.dir + "/config.json",
                text: root.files.config
            },
            settings: {
                path: root.dir + "/settings.json",
                text: root.files.settings
            }
        }, root.facts));
        writer.command = ["sh", "-c", "printf '%s\\n' \"$0\" > \"$1\"", text, root.out];
        writer.running = true;
    }

    FileView {
        path: root.dir + "/config.json"
        printErrors: false
        onLoaded: root.arrive("config", text())
        onLoadFailed: root.arrive("config", null)
    }

    FileView {
        path: root.dir + "/settings.json"
        printErrors: false
        onLoaded: root.arrive("settings", text())
        onLoadFailed: root.arrive("settings", null)
    }

    Process {
        running: true
        command: ["sh", Stack.shellDir + "/helpers/doctor-facts.sh", Stack.shellDir].concat(D.allBins())
        stdout: StdioCollector {
            onStreamFinished: {
                root.facts = D.parseFacts(text);
                root.finish();
            }
        }
    }

    Process {
        id: writer
        onExited: Qt.quit()
    }
}
