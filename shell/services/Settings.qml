pragma Singleton

import QtQuick
import SylStack
import "../lib/settings.mjs" as S

Singleton {
    id: root

    readonly property string home: Stack.env("HOME")
    readonly property string dir: (Stack.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/sylvaris"
    readonly property string path: root.dir + "/settings.json"
    property var raw: ({})
    readonly property var values: S.effectiveSettings(Config.values, root.raw)
    property string notice: ""
    property string editing: ""
    readonly property var shown: root.editing === "" ? root.values : S.screenSettings(root.values, root.editing)
    property string lastWritten: ""
    property bool loadedOnce: false
    property bool frozen: false
    property bool ready: false

    onNoticeChanged: {
        if (root.notice !== "")
            console.warn("sylvaris: " + root.notice);
    }

    function get(key: string): var {
        return S.getPath(root.values, key);
    }

    function at(name: string): var {
        return S.screenSettings(root.values, name || "");
    }

    function put(key: string, value: var): void {
        if (root.editing !== "" && S.screenKey(key))
            root.set("screens." + root.editing + "." + key, value);
        else
            root.set(key, value);
    }

    function trySet(key: string, value: var): bool {
        if (root.frozen || !Object.prototype.hasOwnProperty.call(S.DEFAULT_SETTINGS, key.split(".")[0]) || key.split(".")[0] === "version")
            return false;
        const next = S.effectiveSettings(Config.values, S.setPath(root.raw, key, value));
        if (JSON.stringify(S.getPath(next, key)) !== JSON.stringify(value))
            return false;
        root.set(key, value);
        return true;
    }

    function set(key: string, value: var): void {
        if (root.frozen)
            return;
        root.raw = S.setPath(root.raw, key, value);
        writeTimer.restart();
    }

    function ingest(text: string): void {
        if (text === root.lastWritten)
            return;
        const r = S.parseJson(text);
        if (!r.ok) {
            backup.setText(text);
            if (root.loadedOnce) {
                root.notice = "settings.json is not valid JSON; a copy was saved as settings.json.bak and the last good settings stay in use";
                return;
            }
            root.notice = "settings.json is not valid JSON; a copy was saved as settings.json.bak and defaults are in use";
            root.raw = {};
            return;
        }
        const m = S.migrateSettings(r.value);
        root.loadedOnce = true;
        if (!m.ok) {
            writeTimer.stop();
            root.frozen = true;
            root.notice = m.error;
            root.raw = {};
            return;
        }
        root.frozen = false;
        root.notice = "";
        root.raw = m.value;
    }

    Component.onCompleted: Stack.execDetached(["mkdir", "-p", root.dir])

    Timer {
        id: writeTimer
        interval: 300
        onTriggered: {
            if (root.frozen)
                return;
            const text = S.serialize(Object.assign({
                version: S.SETTINGS_VERSION
            }, root.raw));
            root.lastWritten = text;
            file.setText(text);
        }
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.ingest(text());
            root.ready = true;
        }
        onLoadFailed: error => {
            root.ready = true;
            root.frozen = false;
            if (error !== FileViewError.FileNotFound)
                root.notice = "settings.json could not be read";
        }
    }

    FileView {
        id: backup
        path: root.path + ".bak"
        preload: false
        printErrors: false
    }
}
