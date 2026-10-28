pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import SylStack
import "../lib/settings.mjs" as S
import "../lib/capture.mjs" as C

Singleton {
    id: root

    readonly property var cfg: Settings.values.sounds
    readonly property string dir: S.expandHome(root.cfg.pack, Settings.home)
    property var files: ({})
    property var last: ({})

    function play(event: string): void {
        const file = root.files[event];
        if (!root.cfg.enabled || Demo.enabled || file === undefined)
            return;
        const now = Date.now();
        if (now - (root.last[event] || 0) < 120)
            return;
        root.last[event] = now;
        Stack.execDetached(["pw-play", "--volume", String(root.cfg.volume), file]);
    }

    function refresh(): void {
        const out = {};
        for (let i = 0; i < folder.count; i++)
            out[String(folder.get(i, "fileBaseName"))] = String(folder.get(i, "filePath"));
        root.files = out;
    }

    FolderListModel {
        id: folder
        folder: root.cfg.enabled && root.dir.startsWith("/") ? C.fileUri(root.dir) : ""
        nameFilters: ["*.oga", "*.ogg", "*.wav", "*.flac"]
        showDirs: false
        onCountChanged: root.refresh()
    }
}
