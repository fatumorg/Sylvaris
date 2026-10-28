import QtQuick
import qs
import qs.services
import qs.components
import qs.files
import "../lib/notes.mjs" as N
import "../lib/icons.mjs" as Icons

Item {
    id: bar

    required property var editor
    property bool shown: false
    property bool replacing: false
    property bool caseSensitive: false
    property bool wholeWord: false
    property bool regex: false
    property string done: ""
    readonly property string query: find.text
    readonly property var opts: ({
            caseSensitive: bar.caseSensitive,
            wholeWord: bar.wholeWord,
            regex: bar.regex
        })
    readonly property var matches: bar.shown && bar.editor !== null ? N.findAll(bar.editor.edit.text, find.text, bar.opts) : []
    readonly property int at: {
        const e = bar.editor;
        if (e === null)
            return -1;
        const s = e.edit.selectionStart;
        const t = e.edit.selectionEnd;
        return bar.matches.findIndex(m => m.start === s && m.end === t);
    }
    readonly property string count: {
        if (bar.done !== "" || find.text === "")
            return bar.done;
        if (bar.matches.error)
            return "Not a valid pattern";
        if (bar.matches.length === 0)
            return "No results";
        return bar.at >= 0 ? (bar.at + 1) + " of " + bar.matches.length : bar.matches.length + (bar.matches.length === 1 ? " match" : " matches");
    }

    function open(replace: bool): void {
        const e = bar.editor;
        bar.shown = true;
        bar.replacing = replace && e !== null && !e.readOnly;
        bar.done = "";
        const sel = e === null ? "" : e.edit.selectedText;
        if (sel !== "" && sel.indexOf("\n") < 0 && sel.indexOf("\u2029") < 0)
            find.text = sel;
        find.focusInput();
    }

    function close(): void {
        bar.shown = false;
        if (bar.editor !== null)
            bar.editor.edit.forceActiveFocus();
    }

    function step(forward: bool): void {
        const e = bar.editor;
        const list = bar.matches;
        if (e === null || list.length === 0)
            return;
        const n = list.length;
        const from = e.edit.selectionStart;
        let i;
        if (bar.at >= 0)
            i = (bar.at + (forward ? 1 : n - 1)) % n;
        else if (forward)
            i = Math.max(0, list.findIndex(m => m.start >= from));
        else {
            i = n - 1;
            for (let k = n - 1; k >= 0; k--) {
                if (list[k].start < from) {
                    i = k;
                    break;
                }
            }
        }
        e.edit.select(list[i].start, list[i].end);
    }

    function replaceOne(): void {
        const e = bar.editor;
        if (e === null || e.readOnly)
            return;
        if (bar.at < 0) {
            bar.step(true);
            return;
        }
        const m = bar.matches[bar.at];
        const out = N.replaceAll(e.edit.text.slice(m.start, m.end), find.text, swap.text, bar.opts).text;
        e.edit.remove(m.start, m.end);
        e.edit.insert(m.start, out);
        e.edit.cursorPosition = m.start + out.length;
        bar.step(true);
    }

    function replaceEvery(): void {
        const e = bar.editor;
        if (e === null || e.readOnly)
            return;
        const r = N.replaceAll(e.edit.text, find.text, swap.text, bar.opts);
        if (r.count > 0) {
            const pos = e.edit.cursorPosition;
            e.edit.remove(0, e.edit.length);
            e.edit.insert(0, r.text);
            e.edit.cursorPosition = Math.min(pos, e.edit.length);
        }
        bar.done = "Replaced " + r.count;
    }

    onQueryChanged: bar.done = ""

    implicitHeight: bar.shown ? (bar.replacing ? 86 : 44) : 0
    visible: bar.shown
    clip: true

    component Field: Item {
        id: field

        property alias text: input.text
        property string hint: ""

        signal entered(bool back)

        function focusInput(): void {
            input.forceActiveFocus();
            input.selectAll();
        }

        implicitHeight: 34

        Glass {
            anchors.fill: parent
            radius: height / 2
            inner: true
            flowing: false
            offColor: Theme.tintSoft
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 1.5
            border.color: Theme.accent
            visible: input.activeFocus
        }

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Tokens.fontMono
            font.pixelSize: Tokens.smallSize
            selectByMouse: true
            Keys.onEscapePressed: bar.close()
            Keys.onReturnPressed: event => field.entered((event.modifiers & Qt.ShiftModifier) !== 0)
            Keys.onEnterPressed: event => field.entered((event.modifiers & Qt.ShiftModifier) !== 0)
        }

        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            textFormat: Text.PlainText
            text: field.hint
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }

    Column {
        x: 10
        y: 6
        width: parent.width - 20
        spacing: 8

        Row {
            width: parent.width
            spacing: 6

            Field {
                id: find
                width: parent.width - tools.width - parent.spacing
                hint: "Find"
                onEntered: back => bar.step(!back)
            }

            Row {
                id: tools
                spacing: 6

                Text {
                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: bar.count
                    elide: Text.ElideRight
                    color: bar.matches.error ? Theme.danger : Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }

                PillButton {
                    label: "Aa"
                    primary: bar.caseSensitive
                    onClicked: bar.caseSensitive = !bar.caseSensitive
                }

                PillButton {
                    label: "Word"
                    primary: bar.wholeWord
                    onClicked: bar.wholeWord = !bar.wholeWord
                }

                PillButton {
                    label: ".*"
                    primary: bar.regex
                    onClicked: bar.regex = !bar.regex
                }

                ToolButton {
                    size: 32
                    glyph: Icons.GLYPHS.chevronUp
                    tip: "Previous · Shift+F3"
                    enabled: bar.matches.length > 0
                    onClicked: bar.step(false)
                }

                ToolButton {
                    size: 32
                    glyph: Icons.GLYPHS.chevronDown
                    tip: "Next · F3"
                    enabled: bar.matches.length > 0
                    onClicked: bar.step(true)
                }

                ToolButton {
                    size: 32
                    glyph: Icons.GLYPHS.close
                    tip: "Close · Esc"
                    onClicked: bar.close()
                }
            }
        }

        Row {
            width: parent.width
            spacing: 6
            visible: bar.replacing

            Field {
                id: swap
                width: parent.width - acts.width - parent.spacing
                hint: "Replace with"
                onEntered: bar.replaceOne()
            }

            Row {
                id: acts
                spacing: 6

                PillButton {
                    label: "Replace"
                    enabled: bar.matches.length > 0
                    onClicked: bar.replaceOne()
                }

                PillButton {
                    label: "Replace all"
                    enabled: bar.matches.length > 0
                    onClicked: bar.replaceEvery()
                }
            }
        }
    }
}
