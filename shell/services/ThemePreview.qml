pragma Singleton

import QtQuick
import SylStack
import qs
import "../lib/preview.mjs" as P

Singleton {
    id: root

    property var st: P.idle()
    readonly property bool active: root.st.active
    readonly property string original: root.st.original
    readonly property string applied: root.st.applied
    readonly property string pending: root.st.pending

    function run(r: var): void {
        root.st = r.state;
        if (r.apply !== "")
            Theme.apply(r.apply);
    }

    function begin(id: string): void {
        timer.stop();
        root.st = P.begin(id);
    }

    function settle(id: string): void {
        root.st = P.settle(root.st, id);
        timer.restart();
    }

    function commit(front: string): void {
        timer.stop();
        root.run(P.commit(root.st, front));
    }

    function cancel(): void {
        timer.stop();
        root.run(P.cancel(root.st));
    }

    Timer {
        id: timer
        interval: Tokens.previewDelay
        onTriggered: root.run(P.fire(root.st))
    }
}
