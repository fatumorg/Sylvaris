import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.files
import "../lib/notes.mjs" as N
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FloatingWindow {
    id: win

    required property var notes
    required property int slot
    property int made: 0
    property var next: null
    property var editors: []
    property int tab: 0
    property var asking: null
    property var answer: null
    readonly property var editor: win.editors.length > 0 ? win.editors[Math.min(win.tab, win.editors.length - 1)] : null
    readonly property string answerPath: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/notes-pick-" + Stack.processId + "-" + win.slot
    readonly property var recent: Settings.values.notes.recent

    title: (win.editor === null ? "Notes" : (win.editor.dirty ? "• " : "") + win.editor.title) + " — SylNotes"
    implicitWidth: 980
    implicitHeight: 720
    minimumSize: Qt.size(420, 300)
    color: "transparent"
    BackgroundEffect.blurRegion: Resin.enabled ? blur : null
    onClosed: {
        const notes = win.notes;
        const slot = win.slot;
        Qt.callLater(() => notes.drop(slot));
    }

    Region {
        id: blur
        width: win.width
        height: win.height
    }

    function add(spec: var): var {
        win.next = spec;
        docs.append({
            uid: win.made
        });
        win.made += 1;
        win.tab = win.editors.length - 1;
        return win.editors[win.editors.length - 1];
    }

    function openFile(p: string, swap: var): void {
        const at = win.editors.findIndex(e => e.path === p);
        if (at >= 0) {
            win.tab = at;
            return;
        }
        const e = win.editor;
        if (win.editors.length === 1 && e.path === "" && !e.dirty && !e.recovered) {
            e.dropSwap();
            e.number = 0;
            e.open(p, swap);
            return;
        }
        win.add({
            path: p,
            swap: swap
        });
    }

    function newTab(swap: var): void {
        win.add({
            path: "",
            swap: swap
        });
    }

    function closeTab(i: int): void {
        const e = win.editors[i];
        if (e === undefined)
            return;
        if (e.dirty) {
            win.tab = i;
            win.asking = {
                index: i,
                name: e.title
            };
            return;
        }
        win.removeTab(i);
    }

    function removeTab(i: int): void {
        win.editors[i].dropSwap();
        docs.remove(i);
        if (win.editors.length === 0) {
            win.notes.drop(win.slot);
            return;
        }
        win.tab = Math.min(win.tab > i ? win.tab - 1 : win.tab, win.editors.length - 1);
    }

    function decide(choice: string): void {
        const a = win.asking;
        win.asking = null;
        if (a === null || choice === "cancel")
            return;
        if (choice === "discard") {
            win.removeTab(a.index);
            return;
        }
        win.save(() => win.removeTab(win.editors.indexOf(win.editor)));
    }

    function save(then: var): void {
        const e = win.editor;
        if (e === null || e.readOnly)
            return;
        if (e.path === "") {
            win.saveAs(then);
            return;
        }
        if (e.save() && then)
            then();
    }

    function saveAs(then: var): void {
        const e = win.editor;
        if (e === null)
            return;
        const start = e.path !== "" ? e.path : (win.recent.length > 0 ? F.parentOf(win.recent[0]) : win.notes.home) + "/" + (e.title.replace(/ /g, "-").toLowerCase() + ".txt");
        win.pick("save", start, paths => {
            if (paths.length === 1 && e.saveAs(paths[0]) && then)
                then();
        });
    }

    function openDialog(): void {
        const e = win.editor;
        const start = e !== null && e.path !== "" ? F.parentOf(e.path) : win.notes.home;
        win.pick("open", start, paths => {
            for (const p of paths)
                win.openFile(p, win.notes.claim(p));
        });
    }

    function pick(mode: string, start: string, then: var): void {
        if (picker.running)
            return;
        const out = Ipc.run(["files", "pick", mode, mode === "open" ? "1" : "0", win.answerPath, start]);
        if (out.indexOf("error") === 0) {
            if (win.editor !== null)
                win.editor.problem = "Open and save dialogs need SylFiles; turn it on with: sylvaris set parts.files true";
            return;
        }
        win.answer = then;
        picker.running = true;
    }

    function selectTab(i: int): void {
        if (win.editors.length > 0)
            win.tab = (i + win.editors.length) % win.editors.length;
    }

    function findState(): var {
        return {
            shown: finder.shown,
            replacing: finder.replacing,
            query: finder.query,
            matches: finder.matches.length,
            at: finder.at
        };
    }

    function dropped(urls: var): void {
        for (const u of urls) {
            const s = String(u);
            if (s.indexOf("file://") === 0) {
                const p = decodeURIComponent(s.slice(7));
                win.openFile(p, win.notes.claim(p));
            }
        }
    }

    function raise(): void {
        const t = ToplevelManager.toplevels.values.find(w => w.title === win.title);
        if (t)
            t.activate();
    }

    ListModel {
        id: docs
    }

    Process {
        id: picker
        command: ["sh", "-c", "rm -f \"$1\"; while [ ! -s \"$1\" ]; do sleep 0.2; done; cat \"$1\"; rm -f \"$1\"", "sh", win.answerPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const then = win.answer;
                win.answer = null;
                if (then)
                    then(text.split("\n").filter(l => l !== ""));
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: win.save(null)
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: win.saveAs(null)
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: win.openDialog()
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: win.newTab(null)
    }

    Shortcut {
        sequence: "Ctrl+Shift+N"
        onActivated: win.notes.newWindow([])
    }

    Shortcut {
        sequence: "Alt+Z"
        onActivated: Settings.put("notes.wrap", !Settings.values.notes.wrap)
    }

    Shortcut {
        sequence: "Ctrl+W"
        onActivated: win.closeTab(win.tab)
    }

    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
        onActivated: win.selectTab(win.tab + 1)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]
        onActivated: win.selectTab(win.tab - 1)
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: finder.open(false)
    }

    Shortcut {
        sequence: "Ctrl+H"
        onActivated: finder.open(true)
    }

    Shortcut {
        sequence: "F3"
        onActivated: finder.step(true)
    }

    Shortcut {
        sequence: "Shift+F3"
        onActivated: finder.step(false)
    }

    Shortcut {
        sequence: "Ctrl+G"
        onActivated: jump.open()
    }

    Shortcut {
        sequences: ["Ctrl+=", "Ctrl++"]
        onActivated: win.notes.zoomBy(1)
    }

    Shortcut {
        sequence: "Ctrl+-"
        onActivated: win.notes.zoomBy(-1)
    }

    Shortcut {
        sequence: "Ctrl+0"
        onActivated: win.notes.zoomBy(0)
    }

    Glass {
        anchors.fill: parent
        raised: true
        offColor: Theme.surface
    }

    Item {
        id: body
        anchors.fill: parent
        Window.onActiveChanged: {
            if (Window.active)
                win.notes.last = win;
        }

        ListView {
            id: strip
            x: 10
            y: 8
            width: parent.width - 20 - plus.width - 6
            height: 32
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            interactive: false
            model: win.editors
            currentIndex: win.tab
            onCurrentIndexChanged: strip.positionViewAtIndex(strip.currentIndex, ListView.Contain)

            delegate: Item {
                id: chip
                required property var modelData
                required property int index
                readonly property bool on: chip.index === win.tab
                width: Math.min(220, Math.max(110, (strip.width - strip.spacing * (win.editors.length - 1)) / win.editors.length))
                height: strip.height

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    inner: true
                    flowing: false
                    hot: area.containsMouse
                    lit: chip.on
                    offColor: area.containsMouse ? Theme.tintMid : Theme.tintSoft
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: shut.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: (chip.modelData.dirty ? "• " : "") + chip.modelData.title
                    elide: Text.ElideMiddle
                    color: chip.on ? Theme.onAccent : Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: chip.on ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton)
                            win.closeTab(chip.index);
                        else
                            win.tab = chip.index;
                    }
                }

                Glyph {
                    id: shut
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: chip.on || area.containsMouse || shutArea.containsMouse ? 1 : 0
                    text: Icons.GLYPHS.close
                    size: 12
                    color: shutArea.containsMouse ? Theme.danger : chip.on ? Theme.onAccent : Theme.textDim

                    MouseArea {
                        id: shutArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.closeTab(chip.index)
                    }
                }
            }
        }

        ToolButton {
            id: plus
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: strip.verticalCenter
            size: 30
            glyph: Icons.GLYPHS.plus
            tip: "New tab · Ctrl+N"
            onClicked: win.newTab(null)
        }

        Rectangle {
            id: banner
            readonly property var spec: {
                const e = win.editor;
                if (e === null)
                    return null;
                if (e.problem !== "")
                    return {
                        text: e.problem,
                        actions: e.readOnly ? [] : [["Save as…", () => win.saveAs(null)]]
                    };
                if (e.changedOnDisk)
                    return {
                        text: "This file changed on disk while you were editing it",
                        actions: [["Reload", () => e.reloadDisk()], ["Keep mine", () => e.keepMine()]]
                    };
                if (e.recovered)
                    return {
                        text: "Recovered changes you had not saved",
                        actions: [["Keep", () => e.keepRecovered()], ["Discard", () => e.discardRecovered()]]
                    };
                if (e.why !== "")
                    return {
                        text: e.why + ", so it opens read-only",
                        actions: []
                    };
                return null;
            }
            anchors.top: strip.bottom
            anchors.topMargin: banner.spec !== null ? 8 : 0
            x: 10
            width: parent.width - 20
            height: banner.spec !== null ? 40 : 0
            visible: height > 0
            radius: Tokens.r(10)
            color: Qt.alpha(Theme.accent, 0.16)
            border.color: Qt.alpha(Theme.accent, 0.4)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: acts.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: banner.spec !== null ? banner.spec.text : ""
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                id: acts
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: banner.spec !== null ? banner.spec.actions : []

                    PillButton {
                        required property var modelData
                        label: modelData[0]
                        onClicked: modelData[1]()
                    }
                }
            }
        }

        FindBar {
            id: finder
            anchors.top: banner.bottom
            anchors.topMargin: finder.shown ? 4 : 0
            width: parent.width
            height: finder.implicitHeight
            editor: win.editor
        }

        Item {
            id: page
            anchors.top: finder.bottom
            anchors.topMargin: 8
            anchors.bottom: status.top
            x: 6
            width: parent.width - 12

            Repeater {
                model: docs

                Editor {
                    required property int index
                    anchors.fill: parent
                    notes: win.notes
                    visible: index === win.tab
                    focus: index === win.tab
                }

                onItemAdded: (index, item) => {
                    const list = win.editors.slice();
                    list.splice(index, 0, item);
                    win.editors = list;
                    const spec = win.next;
                    win.next = null;
                    if (spec === null)
                        return;
                    if (spec.path !== "")
                        item.open(spec.path, spec.swap);
                    else
                        item.untitled(win.notes.nextUntitled(), spec.swap);
                }
                onItemRemoved: (index, item) => win.editors = win.editors.filter(e => e !== item)
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: win.editor !== null && win.editor.path === "" && win.editor.edit.length === 0 && win.recent.length > 0

                Text {
                    textFormat: Text.PlainText
                    text: "Recent files"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: win.recent.slice(0, 8)

                    Text {
                        required property string modelData
                        textFormat: Text.PlainText
                        text: F.pretty(modelData, win.notes.home)
                        color: link.containsMouse ? Theme.accent : Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize

                        MouseArea {
                            id: link
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.openFile(parent.modelData, win.notes.claim(parent.modelData))
                        }
                    }
                }
            }
        }

        GotoLine {
            id: jump
            anchors.top: page.top
            anchors.topMargin: 12
            anchors.horizontalCenter: page.horizontalCenter
            z: 5
            editor: win.editor
        }

        NotesBar {
            id: status
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            editor: win.editor
            zoom: win.notes.zoom
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: drop => {
                win.dropped(drop.urls);
                drop.acceptProposedAction();
            }
        }

        Item {
            anchors.fill: parent
            visible: win.asking !== null
            z: 10

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.base, 0.5)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: win.decide("cancel")
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 420)
                height: ask.implicitHeight + 40
                radius: Tokens.r(16)
                color: Theme.surface
                border.color: Theme.line

                Column {
                    id: ask
                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: 16

                    Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: win.asking !== null ? "Save the changes to “" + win.asking.name + "”?" : ""
                        wrapMode: Text.Wrap
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        PillButton {
                            label: "Cancel"
                            onClicked: win.decide("cancel")
                        }

                        PillButton {
                            label: "Don't save"
                            danger: true
                            onClicked: win.decide("discard")
                        }

                        PillButton {
                            label: "Save"
                            primary: true
                            onClicked: win.decide("save")
                        }
                    }
                }
            }
        }
    }
}
