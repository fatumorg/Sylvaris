import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/clip.mjs" as C
import "../lib/icons.mjs" as Icons

Popup {
    id: root

    readonly property var cfg: Settings.values.clip
    readonly property string cacheDir: (Stack.env("XDG_CACHE_HOME") || Stack.env("HOME") + "/.cache") + "/sylvaris/clip"
    readonly property string storePath: (Stack.env("XDG_STATE_HOME") || Stack.env("HOME") + "/.local/state") + "/sylvaris/clip.json"
    property var history: []
    property string query: ""
    property int selected: 0
    property int counter: 0
    readonly property var shownList: C.find(root.history, root.query)

    namespace: "sylclip"
    corner: root.local.placement.clip
    panelWidth: Tokens.clipWidth
    panelHeight: Tokens.clipHeight
    focusTarget: search

    function add(entry: var): void {
        const before = root.history;
        root.history = C.remember(root.history, entry, root.cfg.limit);
        const kept = root.history.map(e => e.path).filter(Boolean);
        const gone = before.filter(e => e.path && kept.indexOf(e.path) < 0).map(e => e.path);
        if (gone.length > 0)
            Stack.execDetached(["rm", "-f"].concat(gone));
        root.save();
    }

    function save(): void {
        if (root.cfg.persist && !Demo.enabled)
            store.setText(JSON.stringify(root.history));
    }

    function copy(entry: var): void {
        if (entry === undefined || entry === null)
            return;
        if (!Demo.enabled) {
            if (entry.kind === "image")
                Stack.execDetached(["sh", "-c", "wl-copy -t image/png < \"$0\"", entry.path]);
            else
                Stack.execDetached(["wl-copy", "--", entry.text]);
        }
        root.add(Object.assign({}, entry, {
            at: Date.now()
        }));
        root.close();
    }

    function pin(id: string): void {
        root.history = root.history.map(e => e.id === id ? Object.assign({}, e, {
                pinned: !e.pinned
            }) : e);
        root.save();
    }

    function remove(id: string): void {
        const hit = root.history.find(e => e.id === id);
        root.history = root.history.filter(e => e.id !== id);
        if (hit && hit.path)
            Stack.execDetached(["rm", "-f", hit.path]);
        root.save();
    }

    function clear(): void {
        const keep = root.history.filter(e => e.pinned);
        const drop = root.history.filter(e => !e.pinned && e.path).map(e => e.path);
        root.history = keep;
        if (drop.length > 0)
            Stack.execDetached(["rm", "-f"].concat(drop));
        if (!Demo.enabled)
            Stack.execDetached(["wl-copy", "--clear"]);
        root.save();
    }

    function state(): var {
        return {
            open: root.shown,
            count: root.history.length,
            items: root.history.map(e => ({
                        kind: e.kind,
                        text: e.kind === "text" ? C.preview(e.text, 60) : e.path,
                        pinned: e.pinned
                    }))
        };
    }

    onOpened: {
        search.text = "";
        root.query = "";
        root.selected = 0;
        search.focusInput();
    }

    Component.onCompleted: {
        if (Demo.enabled)
            root.history = [
                {
                    id: "d1",
                    kind: "text",
                    text: "sylvaris switcher next",
                    pinned: true,
                    at: 0
                },
                {
                    id: "d2",
                    kind: "text",
                    text: "https://github.com/fatumorg/Sylvaris",
                    pinned: false,
                    at: 0
                },
                {
                    id: "d3",
                    kind: "text",
                    text: "Meet at 18:00 by the river,\nbring the blue notebook.",
                    pinned: false,
                    at: 0
                }
            ];
    }

    Process {
        running: !Demo.enabled
        command: ["sh", "-c", "umask 077; for d in \"$(dirname \"$0\")\" \"$0\" \"$(dirname \"$1\")\"; do mkdir -p \"$d\" && chmod 700 \"$d\"; done; find \"$0\" -maxdepth 1 -type f -exec chmod 600 {} +; if [ \"$2\" = true ]; then [ -e \"$1\" ] || : > \"$1\"; chmod 600 \"$1\"; fi; exit 0", root.cacheDir, root.storePath, String(root.cfg.persist)]
    }

    FileView {
        path: root.cfg.persist && !Demo.enabled ? root.storePath : ""
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (Array.isArray(saved) && root.history.length === 0)
                    root.history = saved.slice(0, 500);
            } catch (e) {}
        }
    }

    FileView {
        id: store
        path: root.cfg.persist && !Demo.enabled ? root.storePath : ""
        printErrors: false
        atomicWrites: true
    }

    property bool watchUp: true
    property int watchRetries: 0

    Timer {
        id: watchAgain
        interval: Math.min(60000, 2000 * Math.pow(2, root.watchRetries))
        onTriggered: {
            root.watchRetries++;
            root.watchUp = true;
        }
    }

    Process {
        running: !Demo.enabled && root.watchUp
        command: ["wl-paste", "--watch", "echo", "changed"]
        onExited: {
            root.watchUp = false;
            watchAgain.restart();
        }
        stdout: SplitParser {
            onRead: {
                root.watchRetries = 0;
                if (!grab.running)
                    grab.running = true;
                else
                    grab.again = true;
            }
        }
    }

    Process {
        id: grab
        property bool again: false
        command: ["sh", "-c", "umask 077; t=$(wl-paste --list-types 2>/dev/null) || exit 0; printf '%s\\n\\036\\n' \"$t\"; case \"$t\" in *x-kde-passwordManagerHint*) exit 0 ;; esac; if printf '%s' \"$t\" | grep -q '^text/plain'; then wl-paste -n -t text 2>/dev/null; elif [ \"$1\" = 1 ] && printf '%s' \"$t\" | grep -q '^image/png'; then mkdir -p \"$0\"; f=\"$0/$(date +%s%N).png\"; wl-paste -t image/png > \"$f\" && printf 'IMG %s %s' \"$f\" \"$(md5sum < \"$f\" | cut -c1-32)\"; fi", root.cacheDir, root.cfg.images ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cut = text.indexOf("\n\u001e\n");
                if (cut < 0)
                    return;
                const types = text.slice(0, cut).split("\n");
                const body = text.slice(cut + 3);
                if (C.secret(types) || body === "")
                    return;
                root.counter++;
                const img = /^IMG (\S+) (\w+)$/.exec(body);
                if (img)
                    root.add({
                        id: "c" + Date.now() + "-" + root.counter,
                        kind: "image",
                        path: img[1],
                        hash: img[2],
                        pinned: false,
                        at: Date.now()
                    });
                else
                    root.add({
                        id: "c" + Date.now() + "-" + root.counter,
                        kind: "text",
                        text: body,
                        pinned: false,
                        at: Date.now()
                    });
            }
        }
        onExited: {
            if (grab.again) {
                grab.again = false;
                grab.running = true;
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 20
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
                root.selected = Math.min(root.shownList.length - 1, root.selected + 1);
                list.positionViewAtIndex(root.selected, ListView.Contain);
            } else if (event.key === Qt.Key_Up) {
                root.selected = Math.max(0, root.selected - 1);
                list.positionViewAtIndex(root.selected, ListView.Contain);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.copy(root.shownList[root.selected]);
            } else if (event.key === Qt.Key_Delete && root.shownList[root.selected]) {
                root.remove(root.shownList[root.selected].id);
            } else {
                return;
            }
            event.accepted = true;
        }

        Row {
            id: head
            width: parent.width
            height: 30
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.clipboard
                size: 20
                color: Theme.accent
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard"
                color: Theme.text
                font.family: Tokens.fontDisplay
                font.pixelSize: Tokens.titleSize
                font.weight: Tokens.titleWeight
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: root.history.length === 0 ? "" : root.history.length + (root.history.length === 1 ? " item" : " items")
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }

        RowButton {
            anchors.right: parent.right
            anchors.verticalCenter: head.verticalCenter
            height: 32
            visible: root.history.some(e => !e.pinned)
            icon: Icons.GLYPHS.trash
            label: "Clear"
            onClicked: root.clear()
        }

        TextBox {
            id: search
            anchors.top: head.bottom
            anchors.topMargin: 14
            width: parent.width
            placeholder: "Search the clipboard…"
            onTextChanged: {
                root.query = search.text;
                root.selected = 0;
            }
            Keys.forwardTo: [parent]
        }

        Text {
            textFormat: Text.PlainText
            anchors.centerIn: list
            visible: root.shownList.length === 0
            text: root.history.length === 0 ? "Copy something and it shows up here." : "Nothing matches."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
        }

        ListView {
            id: list
            anchors.top: search.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.shownList

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool picked: row.index === root.selected
                width: list.width
                height: row.modelData.kind === "image" ? 96 : 48

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusRow
                    inner: true
                    lit: row.picked
                    hot: rowArea.containsMouse
                }

                Image {
                    x: 10
                    y: 8
                    width: parent.height * 1.6
                    height: parent.height - 16
                    visible: row.modelData.kind === "image"
                    source: row.modelData.kind === "image" ? "file://" + row.modelData.path : ""
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    textFormat: Text.PlainText
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - tools.width - 28
                    visible: row.modelData.kind === "text"
                    text: row.modelData.kind === "text" ? C.preview(row.modelData.text, 200) : ""
                    elide: Text.ElideRight
                    color: row.picked ? Theme.onAccent : Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.selected = row.index
                    onClicked: root.copy(row.modelData)
                }

                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: [
                            {
                                act: "pin",
                                glyph: Icons.GLYPHS.pin
                            },
                            {
                                act: "delete",
                                glyph: Icons.GLYPHS.close
                            }
                        ]

                        delegate: Glyph {
                            required property var modelData
                            width: 30
                            height: 30
                            visible: modelData.act === "delete" ? rowArea.containsMouse || toolArea.containsMouse || row.picked : row.modelData.pinned || rowArea.containsMouse || toolArea.containsMouse || row.picked
                            text: modelData.glyph
                            size: 15
                            color: modelData.act === "pin" && row.modelData.pinned ? (row.picked ? Theme.onAccent : Theme.accent) : row.picked ? Theme.onAccent : toolArea.containsMouse ? Theme.text : Theme.textDim

                            MouseArea {
                                id: toolArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.modelData.act === "pin")
                                        root.pin(row.modelData.id);
                                    else
                                        root.remove(row.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
