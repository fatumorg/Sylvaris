import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/keyboard.mjs" as K

Scope {
    id: root

    property bool wanted: false
    property var screenInfo: null
    readonly property var cfg: Settings.values.keyboard
    property string page: "letters"
    property bool shift: false
    property bool caps: false
    property bool alt: false
    property string mode: "pointer"
    property int row: 0
    property int col: 0
    property string preview: ""
    property bool sending: false
    property var queue: []
    property int tries: 0
    property bool closeAfter: false
    readonly property var rows: K.rowsFor(root.cfg.layout, root.page)
    readonly property bool upper: root.shift !== (root.caps && root.page === "letters")
    readonly property int unit: Math.round(Tokens.keyboardUnit * root.cfg.size)
    readonly property int gap: Math.round(root.unit / 9)
    readonly property bool focusing: root.wanted && root.mode === "focus" && !root.sending
    property Item grid: null

    signal opened

    function open(how: string): void {
        if (how !== "" && how !== "pointer" && how !== "focus")
            throw new Error("usage: keyboard open [pointer|focus]");
        root.mode = how === "focus" ? "focus" : "pointer";
        if (root.wanted)
            return;
        root.screenInfo = Compositor.screenFor(Compositor.focusedName());
        root.reset();
        root.wanted = true;
        root.opened();
    }

    function close(): void {
        root.wanted = false;
        root.preview = "";
        root.queue = [];
        root.closeAfter = false;
        root.sending = false;
        flushTimer.stop();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open("");
    }

    function toggleOn(screen: var): void {
        if (root.wanted) {
            root.close();
            return;
        }
        root.open("");
        root.screenInfo = screen;
    }

    function reset(): void {
        root.page = "letters";
        root.shift = false;
        root.alt = false;
        root.row = 1;
        root.col = 1;
        root.preview = "";
    }

    function type(text: string): void {
        if (typeof text !== "string" || text === "" || text.length > 4096)
            throw new Error("usage: keyboard type <text> (1 to 4096 characters)");
        if (!VirtualInput.available)
            throw new Error("this compositor does not accept virtual keyboard input");
        if (root.focusing || root.sending) {
            root.queue = root.queue.concat([{
                    text: text
                }]);
            root.flush("", false);
            return;
        }
        if (!VirtualInput.type(text))
            throw new Error("could not type this text; it has too many different characters at once");
    }

    function state(): var {
        return {
            open: root.wanted,
            mode: root.mode,
            page: root.page,
            shift: root.shift,
            caps: root.caps,
            alt: root.alt,
            preview: root.preview,
            focus: [root.row, root.col],
            layout: root.cfg.layout,
            available: VirtualInput.available,
            gamepads: pad.count,
            keys: keyRects()
        };
    }

    function keyRects(): var {
        const out = [];
        if (!root.wanted || root.grid === null || root.screenInfo === null)
            return out;
        const top = root.screenInfo.height - root.grid.Window.height;
        for (const r of root.grid.children) {
            if (r.keys === undefined)
                continue;
            for (const k of r.keys.children) {
                if (k.label === undefined)
                    continue;
                const p = k.mapToItem(null, 0, 0);
                out.push({
                    label: k.label,
                    x: Math.round(p.x + k.width / 2),
                    y: Math.round(top + p.y + k.height / 2)
                });
            }
        }
        return out;
    }

    function flush(sym: string, done: bool): void {
        const items = root.queue.slice();
        if (root.preview !== "")
            items.push({
                text: root.preview
            });
        if (sym !== "")
            items.push({
                sym: sym
            });
        root.queue = items;
        root.preview = "";
        root.closeAfter = root.closeAfter || done;
        root.sending = true;
        if (!flushTimer.running) {
            root.tries = 0;
            flushTimer.start();
        }
    }

    function hit(key: var, pointer: bool): void {
        const leaving = pointer && root.mode === "focus";
        if (leaving) {
            root.mode = "pointer";
            root.flush("", false);
        }
        if (key.action === "shift" || key.action === "caps" || key.action === "alt" || key.action === "page") {
            if (key.action === "shift")
                root.shift = !root.shift;
            else if (key.action === "caps")
                root.caps = !root.caps;
            else if (key.action === "alt")
                root.alt = !root.alt;
            else
                root.turn();
            return;
        }
        const text = K.textFor(key, root.upper, root.alt);
        if (root.mode === "focus") {
            if (key.action === "backspace" && root.preview !== "")
                root.preview = root.preview.slice(0, -1);
            else if (text !== "")
                root.preview = (root.preview + text).slice(0, 4096);
            else
                root.flush(key.sym, key.sym === "Return");
        } else if (root.sending) {
            if (text !== "")
                root.queue = root.queue.concat([{
                        text: text
                    }]);
            else
                root.flush(key.sym, false);
        } else {
            VirtualInput.tap(K.symFor(key, root.upper, root.alt), []);
        }
        root.shift = false;
        root.alt = false;
    }

    function turn(): void {
        root.page = root.page === "letters" ? "symbols" : "letters";
        root.row = Math.min(root.row, root.rows.length - 1);
        root.col = Math.min(root.col, root.rows[root.row].length - 1);
    }

    function press(button: string): void {
        const known = ["up", "down", "left", "right", "a", "b", "x", "y", "select", "start", "combo"];
        if (known.indexOf(button) < 0)
            throw new Error("usage: keyboard press <" + known.join("|") + ">");
        if (button === "combo") {
            if (!root.cfg.combo)
                return;
            if (!root.wanted)
                root.open("focus");
            else if (root.preview !== "" || root.sending)
                root.flush("", true);
            else
                root.close();
            return;
        }
        if (!root.wanted)
            return;
        root.mode = "focus";
        if (["up", "down", "left", "right"].indexOf(button) >= 0) {
            const to = K.move(root.rows, root.row, root.col, button);
            root.row = to.r;
            root.col = to.c;
        } else if (button === "a") {
            root.hit(root.rows[root.row][root.col], false);
        } else if (button === "b") {
            root.close();
        } else if (button === "x") {
            root.preview = root.preview.slice(0, -1);
        } else if (button === "y") {
            root.preview = (root.preview + " ").slice(0, 4096);
        } else if (button === "select") {
            root.shift = !root.shift;
        } else if (button === "start") {
            root.flush("", true);
        }
    }

    Gamepad {
        id: pad
        enabled: root.cfg.gamepad && (root.wanted || root.cfg.combo)
        grabbed: root.focusing
        onPressed: button => root.press(button)
    }

    Timer {
        id: flushTimer
        interval: 120
        onTriggered: {
            if (root.grid !== null && root.grid.Window.active && root.tries < 15) {
                root.tries++;
                flushTimer.start();
                return;
            }
            const items = root.queue;
            root.queue = [];
            for (const item of items) {
                if (item.text !== undefined)
                    VirtualInput.type(item.text);
                else
                    VirtualInput.tap(item.sym, []);
            }
            root.sending = false;
            if (root.closeAfter)
                root.close();
        }
    }

    LazyLoader {
        active: root.wanted

        PanelWindow {
            id: win
            screen: root.screenInfo
            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: panel.height + Tokens.edgeMargin * 2
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylkeyboard"
            WlrLayershell.keyboardFocus: root.focusing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region {
                item: panel
            }

            Item {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.edgeMargin
                width: Math.min(win.width - Tokens.edgeMargin * 2, root.unit * 15 + root.gap * 16)
                height: column.implicitHeight + root.gap * 2
                focus: true

                Keys.onPressed: event => {
                    if (root.sending) {
                        event.accepted = true;
                        return;
                    }
                    const map = {
                        [Qt.Key_Up]: "up",
                        [Qt.Key_Down]: "down",
                        [Qt.Key_Left]: "left",
                        [Qt.Key_Right]: "right",
                        [Qt.Key_Return]: "a",
                        [Qt.Key_Enter]: "a",
                        [Qt.Key_Select]: "a",
                        [Qt.Key_Escape]: "b",
                        [Qt.Key_Back]: "b",
                        [Qt.Key_Backspace]: "x",
                        [Qt.Key_MediaPlay]: "start",
                        [Qt.Key_Menu]: "start"
                    };
                    const b = map[event.key];
                    if (b === undefined)
                        return;
                    root.press(b);
                    event.accepted = true;
                }

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    role: "panel"
                }

                Column {
                    id: column
                    anchors.fill: parent
                    anchors.margins: root.gap
                    spacing: root.gap

                    Item {
                        width: parent.width
                        height: root.mode === "focus" ? root.unit * 0.8 : 0
                        visible: height > 0

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.gap
                            width: parent.width - root.gap * 2
                            elide: Text.ElideLeft
                            text: root.preview === "" ? "Type with the d-pad, then press Start" : root.preview
                            color: root.preview === "" ? Theme.textDim : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.titleSize
                        }
                    }

                    Column {
                        id: grid
                        width: parent.width
                        spacing: root.gap
                        Component.onCompleted: root.grid = grid
                        Component.onDestruction: root.grid = null

                        Repeater {
                            model: root.rows.length

                            Item {
                                id: line
                                required property int index
                                readonly property var cells: root.rows[line.index]
                                readonly property real total: line.cells.reduce((s, k) => s + k.width, 0)
                                readonly property real per: (grid.width - root.gap * (line.cells.length - 1)) / line.total
                                property alias keys: keys
                                width: grid.width
                                height: root.unit

                                Row {
                                    id: keys
                                    spacing: root.gap

                                    Repeater {
                                        model: line.cells.length

                                        KeyCap {
                                            required property int index
                                            readonly property var key: line.cells[index]
                                            width: key.width * line.per
                                            height: root.unit
                                            label: K.labelFor(key, root.upper, root.alt)
                                            lit: key.action === "shift" && root.shift || key.action === "caps" && root.caps || key.action === "alt" && root.alt
                                            focused: root.mode === "focus" && root.row === line.index && root.col === index
                                            repeats: key.action === "backspace"
                                            enabled: key.action !== undefined || VirtualInput.available
                                            onHit: root.hit(key, true)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
