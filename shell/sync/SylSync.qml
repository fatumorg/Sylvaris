import QtQuick
import SylStack
import qs.services

Scope {
    id: root

    readonly property bool wanted: false
    property var screenInfo: null

    signal opened

    function open(): void {
        Ipc.run(["settings", "open", "sync"]);
    }

    function close(): void {
    }

    function toggle(): void {
        root.open();
    }

    function toggleOn(screen: var): void {
        root.open();
    }
}
