import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/annotate.mjs" as A
import "../lib/icons.mjs" as Icons
import "../lib/capture.mjs" as Cap

Scope {
    id: root

    property string file: ""
    property string saveTo: A.editedName(root.file)
    property var screenInfo: null
    property string tool: "arrow"
    property color ink: A.INKS[0]
    property int stroke: 4
    property var history: A.emptyHistory()
    property var draft: null
    property var typing: null
    property string saved: ""
    property string problem: ""
    property string hint: ""
    property real imageW: 0
    property real imageH: 0
    property real reveal: 0
    readonly property bool loaded: root.imageW > 0 && root.imageH > 0
    readonly property var crop: {
        let c = null;
        for (const m of root.history.items) {
            if (m.tool === "crop")
                c = m.rect;
        }
        return c;
    }
    readonly property var marks: root.history.items.filter(m => m.tool !== "crop")
    readonly property var view: root.crop !== null ? root.crop : ({
            x: 0,
            y: 0,
            w: root.imageW,
            h: root.imageH
        })
    readonly property var tools: [
        {
            id: "pen",
            name: "Pen",
            glyph: Icons.GLYPHS.pencil
        },
        {
            id: "highlighter",
            name: "Highlighter",
            glyph: Icons.GLYPHS.highlighter
        },
        {
            id: "line",
            name: "Line",
            glyph: Icons.GLYPHS.line
        },
        {
            id: "arrow",
            name: "Arrow",
            glyph: Icons.GLYPHS.arrow
        },
        {
            id: "rect",
            name: "Rectangle",
            glyph: Icons.GLYPHS.rectangle
        },
        {
            id: "ellipse",
            name: "Ellipse",
            glyph: Icons.GLYPHS.ellipse
        },
        {
            id: "text",
            name: "Text",
            glyph: Icons.GLYPHS.text
        },
        {
            id: "pixelate",
            name: "Pixelate",
            glyph: Icons.GLYPHS.pixelate
        },
        {
            id: "crop",
            name: "Crop",
            glyph: Icons.GLYPHS.crop
        }
    ]

    signal done

    function keyFor(tool: string): string {
        for (const k of Object.keys(A.TOOL_KEYS)) {
            if (A.TOOL_KEYS[k] === tool)
                return k.toUpperCase();
        }
        return "";
    }

    function state(): var {
        return {
            open: root.file !== "",
            file: root.file,
            loaded: root.loaded,
            tool: root.tool,
            ink: String(root.ink),
            stroke: root.stroke,
            marks: root.marks.length,
            undo: root.history.undone.length,
            crop: root.crop,
            width: root.view.w,
            height: root.view.h,
            saved: root.saved,
            problem: root.problem
        };
    }

    function close(): void {
        root.done();
    }

    function add(m: var): void {
        if (A.isMark(m))
            root.history = A.push(root.history, m);
    }

    function undo(): void {
        root.history = A.undo(root.history);
    }

    function redo(): void {
        root.history = A.redo(root.history);
    }

    function clear(): void {
        if (root.history.items.length > 0)
            root.history = {
                items: [],
                undone: root.history.items.slice().reverse()
            };
    }

    function pick(tool: string): void {
        root.commitText();
        root.tool = tool;
    }

    function commitText(): void {
        if (root.typing !== null) {
            root.add(Object.assign({}, root.typing));
            root.typing = null;
        }
        if (winLoader.item)
            winLoader.item.refocus();
    }

    function exportTo(path: string, then: var): void {
        root.commitText();
        const target = winLoader.item ? winLoader.item.frame : null;
        if (target === null || !root.loaded) {
            root.problem = "the screenshot is not loaded yet";
            return;
        }
        target.grabToImage(result => {
            if (result.saveToFile(path)) {
                root.problem = "";
                then(path);
            } else {
                root.problem = "could not write " + path;
            }
        }, Qt.size(root.view.w, root.view.h));
    }

    function save(): void {
        root.exportTo(root.saveTo, path => {
            root.saved = path;
            if (!Demo.enabled)
                Stack.execDetached(["notify-send", "-a", "Sylvaris", "-i", path, "Edited screenshot saved", path]);
        });
    }

    function copy(): void {
        root.exportTo((Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris-edit.png", path => {
            root.saved = path;
            Stack.execDetached(["sh", "-c", "wl-copy -t image/png < \"$0\" >/dev/null 2>&1", path]);
        });
    }

    function paintMark(ctx: var, m: var): void {
        ctx.globalAlpha = m.tool === "highlighter" ? 0.35 : 1;
        ctx.strokeStyle = m.color;
        ctx.fillStyle = m.color;
        ctx.lineWidth = m.tool === "highlighter" ? m.width * 4 : m.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        if (m.points !== undefined) {
            ctx.moveTo(m.points[0].x, m.points[0].y);
            for (let i = 1; i < m.points.length; i++)
                ctx.lineTo(m.points[i].x, m.points[i].y);
            ctx.stroke();
        } else if (m.tool === "line" || m.tool === "arrow") {
            ctx.moveTo(m.from.x, m.from.y);
            ctx.lineTo(m.to.x, m.to.y);
            ctx.stroke();
            if (m.tool === "arrow") {
                const w = A.arrowHead(m.from.x, m.from.y, m.to.x, m.to.y, Math.max(14, m.width * 4.5));
                ctx.beginPath();
                ctx.moveTo(m.to.x, m.to.y);
                ctx.lineTo(w[0].x, w[0].y);
                ctx.lineTo(w[1].x, w[1].y);
                ctx.closePath();
                ctx.fill();
            }
        } else if (m.tool === "rect") {
            ctx.strokeRect(m.rect.x, m.rect.y, m.rect.w, m.rect.h);
        } else if (m.tool === "ellipse") {
            ctx.ellipse(m.rect.x, m.rect.y, m.rect.w, m.rect.h);
            ctx.stroke();
        }
    }

    function key(event: var): void {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const letter = event.text.toLowerCase();
        if (ctrl && event.key === Qt.Key_Z && shift)
            root.redo();
        else if (ctrl && event.key === Qt.Key_Z)
            root.undo();
        else if (ctrl && event.key === Qt.Key_Y)
            root.redo();
        else if (ctrl && event.key === Qt.Key_S)
            root.save();
        else if (ctrl && event.key === Qt.Key_C)
            root.copy();
        else if (event.key === Qt.Key_Escape && root.draft !== null)
            root.draft = null;
        else if (event.key === Qt.Key_Escape)
            root.close();
        else if (event.key === Qt.Key_Delete)
            root.clear();
        else if (!ctrl && A.TOOL_KEYS[letter] !== undefined)
            root.pick(A.TOOL_KEYS[letter]);
        else if (!ctrl && ["1", "2", "3"].indexOf(event.text) >= 0)
            root.stroke = A.WIDTHS[Number(event.text) - 1];
        else
            return;
        event.accepted = true;
    }

    NumberAnimation {
        id: enter
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: Tokens.enterDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    Component.onCompleted: enter.restart()

    component EditorButton: Item {
        id: button

        property string glyph: ""
        property string label: ""
        property bool active: false
        property bool usable: true
        property color swatch: "transparent"

        signal clicked

        width: 40
        height: 40
        opacity: button.usable ? 1 : 0.35
        scale: area.pressed && button.usable ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.stateDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.enterCurve
            }
        }

        Glass {
            anchors.fill: parent
            radius: height / 2
            inner: true
            lit: button.active
            hot: area.containsMouse && button.usable
        }

        Glyph {
            anchors.centerIn: parent
            visible: button.glyph !== ""
            text: button.glyph
            size: 19
            color: button.active ? Theme.onAccent : Theme.text
        }

        Rectangle {
            anchors.centerIn: parent
            visible: button.swatch.a > 0
            width: button.active ? 22 : 18
            height: width
            radius: width / 2
            color: button.swatch
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.35)

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            visible: button.activeFocus
            color: "transparent"
            border.width: 2
            border.color: Theme.accentHi
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
            onContainsMouseChanged: root.hint = area.containsMouse ? button.label : root.hint === button.label ? "" : root.hint
        }
    }

    component Divider: Rectangle {
        width: 1
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.line
    }

    LazyLoader {
        id: winLoader
        active: root.file !== ""

        PanelWindow {
            id: win

            property alias frame: frame

            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylcapture-editor"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            function refocus(): void {
                keys.forceActiveFocus();
            }

            Component.onCompleted: keys.forceActiveFocus()

            Backdrop {
                anchors.fill: parent
                reveal: root.reveal
                dim: 0.55
            }

            Item {
                id: keys
                focus: true
                Keys.onPressed: event => root.key(event)
            }

            Item {
                id: area
                readonly property var f: root.loaded ? A.fit(root.view.w, root.view.h, area.width, area.height) : ({
                        scale: 1,
                        x: 0,
                        y: 0
                    })
                anchors.fill: parent
                anchors.topMargin: 112
                anchors.bottomMargin: 72
                anchors.leftMargin: 56
                anchors.rightMargin: 56
                opacity: root.reveal
                scale: 0.97 + 0.03 * root.reveal

                function at(mx: real, my: real): var {
                    const p = A.toImage(mx, my, area.f, root.view.w, root.view.h);
                    return {
                        x: p.x + root.view.x,
                        y: p.y + root.view.y
                    };
                }

                Rectangle {
                    x: frame.x - 1
                    y: frame.y - 1
                    width: root.view.w * area.f.scale + 2
                    height: root.view.h * area.f.scale + 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.line
                    visible: root.loaded
                }

                Item {
                    id: frame
                    x: area.f.x
                    y: area.f.y
                    width: root.view.w
                    height: root.view.h
                    scale: area.f.scale
                    transformOrigin: Item.TopLeft
                    clip: true

                    Item {
                        id: sheet
                        x: -root.view.x
                        y: -root.view.y
                        width: root.imageW
                        height: root.imageH

                        Image {
                            id: photo
                            source: root.file === "" ? "" : Cap.fileUri(root.file)
                            cache: false
                            smooth: true
                            onStatusChanged: {
                                if (photo.status === Image.Ready) {
                                    root.imageW = photo.implicitWidth;
                                    root.imageH = photo.implicitHeight;
                                } else if (photo.status === Image.Error) {
                                    root.problem = "could not open " + root.file;
                                }
                            }
                        }

                        Repeater {
                            model: root.marks.concat(root.draft !== null ? [root.draft] : []).filter(m => m.tool === "pixelate")

                            delegate: ShaderEffectSource {
                                required property var modelData
                                x: modelData.rect.x
                                y: modelData.rect.y
                                width: modelData.rect.w
                                height: modelData.rect.h
                                sourceItem: photo
                                sourceRect: Qt.rect(modelData.rect.x, modelData.rect.y, Math.max(1, modelData.rect.w), Math.max(1, modelData.rect.h))
                                textureSize: Qt.size(Math.max(1, Math.round(modelData.rect.w / 14)), Math.max(1, Math.round(modelData.rect.h / 14)))
                                smooth: false
                            }
                        }

                        Canvas {
                            id: canvas
                            anchors.fill: parent
                            renderStrategy: Canvas.Cooperative

                            onPaint: {
                                const ctx = canvas.getContext("2d");
                                ctx.reset();
                                for (const m of root.marks) {
                                    if (m.tool !== "text" && m.tool !== "pixelate")
                                        root.paintMark(ctx, m);
                                }
                            }

                            Connections {
                                target: root
                                function onHistoryChanged() {
                                    canvas.requestPaint();
                                }
                            }
                        }

                        Repeater {
                            model: root.marks.filter(m => m.tool === "text")

                            delegate: Text {
                                required property var modelData
                                x: modelData.at.x
                                y: modelData.at.y
                                text: modelData.text
                                color: modelData.color
                                font.family: Tokens.fontUi
                                font.pixelSize: modelData.size
                                font.weight: Font.DemiBold
                                style: Text.Outline
                                styleColor: Qt.alpha(Theme.base, 0.55)
                            }
                        }

                        TextInput {
                            id: input
                            visible: root.typing !== null
                            x: root.typing !== null ? root.typing.at.x : 0
                            y: root.typing !== null ? root.typing.at.y : 0
                            color: root.typing !== null ? root.typing.color : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: root.typing !== null ? root.typing.size : 16
                            font.weight: Font.DemiBold
                            cursorVisible: true
                            onTextEdited: {
                                if (root.typing !== null)
                                    root.typing = Object.assign({}, root.typing, {
                                        text: input.text
                                    });
                            }
                            Keys.onReturnPressed: {
                                root.commitText();
                                keys.forceActiveFocus();
                            }
                            Keys.onEnterPressed: {
                                root.commitText();
                                keys.forceActiveFocus();
                            }
                            Keys.onEscapePressed: {
                                root.typing = null;
                                keys.forceActiveFocus();
                            }
                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier) !== 0)
                                    root.key(event);
                            }
                        }

                        Item {
                            readonly property var r: root.draft !== null && root.draft.tool === "crop" ? root.draft.rect : null
                            anchors.fill: parent
                            visible: r !== null

                            Rectangle {
                                x: 0
                                y: 0
                                width: parent.width
                                height: parent.r !== null ? parent.r.y : 0
                                color: Qt.alpha(Theme.base, 0.6)
                            }

                            Rectangle {
                                x: 0
                                y: parent.r !== null ? parent.r.y + parent.r.h : 0
                                width: parent.width
                                height: parent.r !== null ? parent.height - parent.r.y - parent.r.h : 0
                                color: Qt.alpha(Theme.base, 0.6)
                            }

                            Rectangle {
                                x: 0
                                y: parent.r !== null ? parent.r.y : 0
                                width: parent.r !== null ? parent.r.x : 0
                                height: parent.r !== null ? parent.r.h : 0
                                color: Qt.alpha(Theme.base, 0.6)
                            }

                            Rectangle {
                                x: parent.r !== null ? parent.r.x + parent.r.w : 0
                                y: parent.r !== null ? parent.r.y : 0
                                width: parent.r !== null ? parent.width - parent.r.x - parent.r.w : 0
                                height: parent.r !== null ? parent.r.h : 0
                                color: Qt.alpha(Theme.base, 0.6)
                            }

                            Rectangle {
                                x: parent.r !== null ? parent.r.x : 0
                                y: parent.r !== null ? parent.r.y : 0
                                width: parent.r !== null ? parent.r.w : 0
                                height: parent.r !== null ? parent.r.h : 0
                                color: "transparent"
                                border.width: 2 / area.f.scale
                                border.color: Theme.accentHi
                            }
                        }
                    }
                }

                Canvas {
                    id: draftCanvas
                    x: frame.x
                    y: frame.y
                    width: root.view.w * area.f.scale
                    height: root.view.h * area.f.scale
                    renderStrategy: Canvas.Cooperative

                    onPaint: {
                        const ctx = draftCanvas.getContext("2d");
                        ctx.reset();
                        const d = root.draft;
                        if (d === null || d.tool === "pixelate" || d.tool === "crop")
                            return;
                        const k = area.f.scale;
                        ctx.setTransform(k, 0, 0, k, -root.view.x * k, -root.view.y * k);
                        root.paintMark(ctx, d);
                    }

                    Connections {
                        target: root
                        function onDraftChanged() {
                            draftCanvas.requestPaint();
                        }
                    }
                }

                MouseArea {
                    x: frame.x
                    y: frame.y
                    width: root.view.w * area.f.scale
                    height: root.view.h * area.f.scale
                    enabled: root.loaded
                    hoverEnabled: true
                    cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor

                    function point(mouse: var): var {
                        return area.at(mouse.x + frame.x, mouse.y + frame.y);
                    }

                    onPressed: mouse => {
                        const p = point(mouse);
                        const width = root.stroke / area.f.scale;
                        if (root.tool === "text") {
                            root.commitText();
                            root.typing = {
                                tool: "text",
                                at: p,
                                text: "",
                                color: String(root.ink),
                                size: Math.round((14 + root.stroke * 4) / area.f.scale)
                            };
                            input.text = "";
                            input.forceActiveFocus();
                            return;
                        }
                        root.commitText();
                        keys.forceActiveFocus();
                        if (root.tool === "pen" || root.tool === "highlighter")
                            root.draft = {
                                tool: root.tool,
                                color: String(root.ink),
                                width: width,
                                points: [p]
                            };
                        else if (root.tool === "line" || root.tool === "arrow")
                            root.draft = {
                                tool: root.tool,
                                color: String(root.ink),
                                width: width,
                                from: p,
                                to: p
                            };
                        else
                            root.draft = {
                                tool: root.tool,
                                color: String(root.ink),
                                width: width,
                                start: p,
                                rect: A.normRect(p, p)
                            };
                    }

                    onPositionChanged: mouse => {
                        if (root.draft === null || !pressed)
                            return;
                        const p = point(mouse);
                        const d = root.draft;
                        if (d.points !== undefined)
                            root.draft = Object.assign({}, d, {
                                points: A.addPoint(d.points, p, 1.5 / area.f.scale)
                            });
                        else if (d.from !== undefined)
                            root.draft = Object.assign({}, d, {
                                to: p
                            });
                        else
                            root.draft = Object.assign({}, d, {
                                rect: A.normRect(d.start, p)
                            });
                    }

                    onReleased: {
                        if (root.draft === null)
                            return;
                        const d = Object.assign({}, root.draft);
                        delete d.start;
                        if (d.tool === "crop")
                            d.rect = A.clampRect(d.rect, root.imageW, root.imageH);
                        root.draft = null;
                        root.add(d);
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    visible: !root.loaded
                    text: root.problem !== "" ? root.problem : "Opening the screenshot…"
                    color: root.problem !== "" ? Theme.danger : Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                }
            }

            Item {
                id: bar
                anchors.horizontalCenter: parent.horizontalCenter
                y: 32 - 12 * (1 - root.reveal)
                width: tools.implicitWidth + 28
                height: 56
                opacity: root.reveal

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    raised: true
                }

                Row {
                    id: tools
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: root.tools

                        delegate: EditorButton {
                            required property var modelData
                            glyph: modelData.glyph
                            label: modelData.name + "  ·  " + root.keyFor(modelData.id)
                            active: root.tool === modelData.id
                            onClicked: root.pick(modelData.id)
                        }
                    }

                    Divider {}

                    Repeater {
                        model: [Theme.accent].concat(A.INKS)

                        delegate: EditorButton {
                            required property var modelData
                            required property int index
                            swatch: modelData
                            label: index === 0 ? "Theme colour" : "Colour"
                            active: Qt.colorEqual(root.ink, modelData)
                            onClicked: root.ink = modelData
                        }
                    }

                    Divider {}

                    Repeater {
                        model: A.WIDTHS

                        delegate: EditorButton {
                            id: widthButton
                            required property var modelData
                            required property int index
                            label: ["Thin", "Medium", "Thick"][index] + "  ·  " + (index + 1)
                            active: root.stroke === modelData
                            onClicked: root.stroke = modelData

                            Rectangle {
                                anchors.centerIn: parent
                                width: 6 + widthButton.modelData * 2
                                height: width
                                radius: width / 2
                                color: widthButton.active ? Theme.onAccent : Theme.text
                            }
                        }
                    }

                    Divider {}

                    EditorButton {
                        glyph: Icons.GLYPHS.undo
                        label: "Undo  ·  Ctrl+Z"
                        usable: root.history.items.length > 0
                        onClicked: root.undo()
                    }

                    EditorButton {
                        glyph: Icons.GLYPHS.redo
                        label: "Redo  ·  Ctrl+Shift+Z"
                        usable: root.history.undone.length > 0
                        onClicked: root.redo()
                    }

                    EditorButton {
                        glyph: Icons.GLYPHS.trash
                        label: "Clear everything  ·  Delete"
                        usable: root.history.items.length > 0
                        onClicked: root.clear()
                    }

                    Divider {}

                    EditorButton {
                        glyph: Icons.GLYPHS.copy
                        label: "Copy  ·  Ctrl+C"
                        usable: root.loaded
                        onClicked: root.copy()
                    }

                    EditorButton {
                        glyph: Icons.GLYPHS.save
                        label: "Save next to the original  ·  Ctrl+S"
                        usable: root.loaded
                        onClicked: root.save()
                    }

                    EditorButton {
                        glyph: Icons.GLYPHS.close
                        label: "Close  ·  Esc"
                        onClicked: root.close()
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: bar.horizontalCenter
                anchors.top: bar.bottom
                anchors.topMargin: 10
                opacity: root.hint !== "" ? 1 : 0
                text: root.hint
                color: Theme.textSoft
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                opacity: root.reveal
                width: Math.min(implicitWidth, parent.width - 80)
                elide: Text.ElideMiddle
                text: root.problem !== "" && root.loaded ? root.problem : root.saved !== "" ? "Saved to " + root.saved : root.file.split("/").pop() + (root.loaded ? "  ·  " + Math.round(root.view.w) + " × " + Math.round(root.view.h) : "")
                color: root.problem !== "" && root.loaded ? Theme.danger : root.saved !== "" ? Theme.accentHi : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }
    }
}
