import QtQuick
import SylStack
import qs
import qs.services
import "../lib/notes.mjs" as N

FocusScope {
    id: ed

    required property var notes
    property string path: ""
    property string key: ""
    property int number: 0
    property string eol: "lf"
    property string savedText: ""
    property string writing: ""
    property bool readOnly: false
    property string why: ""
    property string problem: ""
    property bool changedOnDisk: false
    property bool recovered: false
    property bool fresh: false
    property bool swapped: false
    property bool ready: false
    property int readError: 0
    property string chosen: ""
    property bool big: false
    readonly property alias edit: edit
    readonly property var cfg: Settings.values.notes
    readonly property bool dirty: ed.ready && !ed.readOnly && edit.text !== ed.savedText
    readonly property string title: N.titleOf(ed.path, ed.number)
    readonly property string language: ed.chosen !== "" ? ed.chosen : ed.found !== null ? ed.found.detected : N.languageFor(ed.path)
    readonly property var found: hl.status === Loader.Ready ? hl.item : null
    readonly property bool highlighted: ed.found !== null && ed.language !== "" && ed.language !== "Plain text"
    readonly property var languages: ed.found !== null ? ed.found.names : []
    readonly property var starts: N.lineStarts(edit.text)
    readonly property int line: N.lineOf(ed.starts, edit.cursorPosition)
    readonly property int column: edit.cursorPosition - ed.starts[ed.line - 1] + 1
    readonly property string swapPath: ed.notes.swapDir + "/" + N.swapName(ed.key)
    readonly property real fontSize: Math.max(6, Math.min(64, ed.cfg.size + ed.notes.zoom))

    function open(p: string, swap: var): void {
        ed.path = p;
        ed.key = p;
        ed.readError = 0;
        file.path = p;
        file.reload();
        const raw = file.text();
        if (ed.readError === FileViewError.FileNotFound) {
            ed.fresh = true;
            ed.apply("");
        } else if (ed.readError !== 0) {
            ed.problem = ed.readError === FileViewError.PermissionDenied ? "You do not have permission to read this file" : ed.readError === FileViewError.NotAFile ? "This is not a file" : "Could not read this file";
            ed.readOnly = true;
            ed.why = ed.problem;
            ed.ready = true;
            return;
        } else {
            ed.apply(raw);
            ed.notes.remember(p);
        }
        if (!swap)
            return;
        ed.swapped = true;
        if (!ed.readOnly && swap.text !== edit.text) {
            edit.text = swap.text;
            ed.recovered = true;
        } else {
            ed.dropSwap();
        }
    }

    function untitled(n: int, swap: var): void {
        ed.number = n;
        ed.key = swap ? swap.key : "untitled-" + Date.now() + "-" + n;
        ed.apply("");
        if (swap) {
            edit.text = swap.text;
            ed.eol = swap.eol === "crlf" ? "crlf" : "lf";
            ed.recovered = true;
            ed.swapped = true;
        }
    }

    function apply(raw: string): void {
        const binary = N.isBinary(raw);
        const lossy = binary ? "" : N.lossy(raw);
        ed.why = binary ? "This looks like a binary file" : lossy !== "" ? lossy : N.readOnlyFor(raw.length) ? "This file is over 10 MB" : "";
        ed.readOnly = ed.why !== "";
        ed.eol = N.detectEol(raw);
        ed.big = raw.length > 1048576;
        const text = binary ? raw.replace(/\u0000/g, "␀") : N.stripEol(raw);
        ed.ready = false;
        if (text !== edit.text)
            edit.text = text;
        ed.savedText = text;
        ed.ready = true;
    }

    function save(): bool {
        if (ed.readOnly || ed.path === "")
            return false;
        ed.problem = "";
        ed.writing = edit.text;
        file.setText(N.withEol(ed.writing, ed.eol));
        return ed.problem === "";
    }

    function saveAs(p: string): bool {
        const old = ed.swapped ? ed.swapPath : "";
        ed.path = p;
        ed.key = p;
        file.path = p;
        ed.readOnly = false;
        ed.why = "";
        const ok = ed.save();
        if (ok && old !== "")
            Stack.execDetached(["rm", "-f", "--", old]);
        return ok;
    }

    function reloadDisk(): void {
        ed.changedOnDisk = false;
        ed.readError = 0;
        file.reload();
        const raw = file.text();
        if (ed.readError === 0)
            ed.apply(raw);
        ed.dropSwap();
    }

    function keepMine(): void {
        ed.changedOnDisk = false;
    }

    function keepRecovered(): void {
        ed.recovered = false;
    }

    function discardRecovered(): void {
        ed.recovered = false;
        edit.text = ed.savedText;
        ed.dropSwap();
    }

    function diskChanged(): void {
        if (ed.path === "" || !ed.ready)
            return;
        ed.readError = 0;
        file.reload();
        const raw = file.text();
        if (ed.readError !== 0)
            return;
        const text = N.stripEol(raw);
        if (text === ed.savedText)
            return;
        if (ed.dirty)
            ed.changedOnDisk = true;
        else
            ed.apply(raw);
    }

    function writeSwap(): void {
        if (!ed.notes.swapReady || ed.key === "")
            return;
        swapFile.path = ed.swapPath;
        swapFile.first = !ed.swapped;
        swapFile.setText(JSON.stringify({
            key: ed.key,
            path: ed.path,
            eol: ed.eol,
            at: Date.now(),
            text: edit.text
        }) + "\n");
        ed.swapped = true;
    }

    function dropSwap(): void {
        swapTimer.stop();
        if (!ed.swapped)
            return;
        ed.swapped = false;
        Stack.execDetached(["rm", "-f", "--", ed.swapPath]);
    }

    function goTo(n: int): void {
        edit.cursorPosition = ed.starts[Math.max(1, Math.min(n, ed.starts.length)) - 1];
        edit.forceActiveFocus();
    }

    function indentUnit(): string {
        return ed.cfg.spaces ? " ".repeat(ed.cfg.tabWidth) : "\t";
    }

    function typed(event: var): bool {
        if (edit.readOnly)
            return false;
        const plain = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
        if (plain && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            const at = edit.selectionStart;
            const before = edit.text.slice(ed.starts[N.lineOf(ed.starts, at) - 1], at);
            edit.remove(edit.selectionStart, edit.selectionEnd);
            edit.insert(at, "\n" + N.nextIndent(before, ed.cfg.tabWidth, ed.cfg.spaces));
            return true;
        }
        if (plain && event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier) === 0) {
            const at = edit.selectionStart;
            edit.remove(edit.selectionStart, edit.selectionEnd);
            edit.insert(at, ed.indentUnit());
            return true;
        }
        if (event.key === Qt.Key_Backtab) {
            const start = ed.starts[ed.line - 1];
            const lead = N.indentOf(edit.text.slice(start, start + 64));
            const cut = lead.charAt(0) === "\t" ? 1 : Math.min(lead.length, ed.cfg.tabWidth);
            if (cut > 0)
                edit.remove(start, start + cut);
            return true;
        }
        return false;
    }

    function show(r: rect): void {
        const x = r.x + edit.x;
        const y = r.y + edit.y;
        if (x < flick.contentX)
            flick.contentX = Math.max(0, x - 24);
        else if (x + r.width > flick.contentX + flick.width)
            flick.contentX = x + r.width - flick.width + 24;
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y - 8);
        else if (y + r.height > flick.contentY + flick.height)
            flick.contentY = y + r.height - flick.height + 8;
    }

    FileView {
        id: file
        preload: false
        atomicWrites: true
        printErrors: false
        watchChanges: ed.path !== ""
        onLoadFailed: error => ed.readError = error
        onSaved: {
            ed.savedText = ed.writing;
            ed.fresh = false;
            ed.changedOnDisk = false;
            ed.recovered = false;
            ed.dropSwap();
            ed.notes.remember(ed.path);
        }
        onSaveFailed: error => ed.problem = error === FileViewError.PermissionDenied ? "You do not have permission to save here" : "Could not save this file"
        onFileChanged: ed.diskChanged()
    }

    FileView {
        id: swapFile
        property bool first: false
        preload: false
        atomicWrites: true
        printErrors: false
        onSaved: {
            if (swapFile.first)
                Stack.execDetached(["chmod", "600", "--", swapFile.path]);
            swapFile.first = false;
        }
    }

    Timer {
        id: swapTimer
        interval: 1000
        onTriggered: {
            if (ed.dirty)
                ed.writeSwap();
            else
                ed.dropSwap();
        }
    }

    Component.onCompleted: {
        ed.notes.bake();
        hl.setSource("Highlighter.qml", {
            ed: ed
        });
    }

    Loader {
        id: hl
        active: ed.cfg.highlight && ed.notes.themeSettled && !ed.big
    }

    FontMetrics {
        id: metrics
        font: edit.font
    }

    Rectangle {
        id: gutter
        width: ed.cfg.lineNumbers ? Math.max(3, String(ed.starts.length).length) * metrics.advanceWidth("0") + 28 : 0
        height: parent.height
        color: Qt.alpha(Theme.base, 0.35)
        visible: width > 0
        clip: true

        Repeater {
            model: {
                if (!ed.cfg.lineNumbers || flick.height <= 0 || edit.contentHeight <= 0 || edit.width <= 0)
                    return [];
                const top = flick.contentY - edit.y;
                const bottom = top + flick.height;
                const out = [];
                const first = N.lineOf(ed.starts, edit.positionAt(0, Math.max(0, top)));
                for (let n = first; n <= ed.starts.length && out.length < 400; n++) {
                    const r = edit.positionToRectangle(ed.starts[n - 1]);
                    if (r.y > bottom)
                        break;
                    out.push({
                        n: n,
                        y: r.y + edit.y - flick.contentY
                    });
                }
                return out;
            }

            Text {
                required property var modelData
                x: 0
                y: modelData.y
                width: gutter.width - 12
                horizontalAlignment: Text.AlignRight
                text: modelData.n
                color: modelData.n === ed.line ? Theme.text : Theme.textDim
                font.family: Tokens.fontMono
                font.pixelSize: ed.fontSize
            }
        }
    }

    Flickable {
        id: flick
        anchors.left: gutter.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentWidth: ed.cfg.wrap ? width : Math.max(width, edit.implicitWidth + 32)
        contentHeight: Math.max(height, edit.contentHeight + 32)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Rectangle {
            y: edit.y + edit.cursorRectangle.y
            width: flick.contentWidth
            height: edit.cursorRectangle.height
            color: Theme.tintSoft
            visible: edit.activeFocus && edit.selectionStart === edit.selectionEnd
        }

        TextEdit {
            id: edit
            x: 12
            y: 8
            width: ed.cfg.wrap ? flick.width - 24 : Math.max(flick.width - 24, edit.implicitWidth)
            textFormat: TextEdit.PlainText
            wrapMode: ed.cfg.wrap ? TextEdit.Wrap : TextEdit.NoWrap
            font.family: Tokens.fontMono
            font.pixelSize: ed.fontSize
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            selectByMouse: true
            persistentSelection: true
            readOnly: ed.readOnly
            tabStopDistance: metrics.advanceWidth(" ") * ed.cfg.tabWidth
            focus: true
            onCursorRectangleChanged: ed.show(edit.cursorRectangle)
            onTextChanged: {
                if (ed.ready)
                    swapTimer.restart();
            }
            Keys.onPressed: event => {
                if (ed.typed(event))
                    event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: edit.y + edit.contentHeight
            cursorShape: Qt.IBeamCursor
            onClicked: {
                edit.forceActiveFocus();
                edit.cursorPosition = edit.length;
            }
        }
    }
}
