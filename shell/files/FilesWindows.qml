import QtQuick
import SylStack

Scope {
    id: root

    property int made: 1
    property var windows: []
    property var last: null
    property string pending: ""
    property var clip: ({
            mode: "",
            items: []
        })
    readonly property var current: root.last !== null && root.windows.indexOf(root.last) >= 0 ? root.last : root.windows.length > 0 ? root.windows[0] : null
    readonly property bool wanted: root.windows.some(w => w.wanted)
    readonly property var screenInfo: root.current !== null ? root.current.screenInfo : null
    readonly property bool windowed: true
    readonly property int count: root.windows.filter(w => w.wanted).length

    signal opened

    function newWindow(path: string): void {
        if (!root.wanted) {
            root.last = root.windows[0];
            root.windows[0].open(path);
            return;
        }
        root.pending = path;
        slots.append({
            slot: root.made
        });
        root.made += 1;
    }

    function drop(slot: int): void {
        Qt.callLater(() => {
            for (let i = slots.count - 1; i > 0; i--) {
                if (slots.get(i).slot === slot)
                    slots.remove(i);
            }
        });
    }

    function close(): void {
        for (const w of root.windows.slice())
            w.close();
    }

    function toggleOn(screen: var): void {
        root.current.toggleOn(screen);
    }

    function toggle(): void {
        root.current.toggle();
    }

    function state(): var {
        return Object.assign(root.current.state(), {
            windows: root.count
        });
    }

    ListModel {
        id: slots

        ListElement {
            slot: 0
        }
    }

    Instantiator {
        model: slots

        SylFiles {
            required property int slot
            hub: root
            hubSlot: slot
            onOpened: root.opened()
        }

        onObjectAdded: (index, w) => {
            const list = root.windows.slice();
            list.splice(index, 0, w);
            root.windows = list;
            if (index > 0) {
                root.last = w;
                w.open(root.pending);
            }
        }
        onObjectRemoved: (index, w) => {
            root.windows = root.windows.filter(x => x !== w);
            if (root.last === w)
                root.last = null;
        }
    }
}
