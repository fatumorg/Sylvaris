import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/widgets.mjs" as Wd
import "../lib/icons.mjs" as Icons

PanelWindow {
    id: canvas

    required property var modelData
    required property var host
    readonly property var cfg: canvas.host.cfg
    readonly property var here: [
        {
            name: canvas.modelData.name,
            width: canvas.modelData.width,
            height: canvas.modelData.height
        }
    ]
    readonly property var ids: canvas.host.shownOn(canvas.modelData.name)
    readonly property bool typing: canvas.host.focusedScreen === canvas.modelData.name || canvas.host.focusedScreen === "" && canvas.host.screens.length > 0 && canvas.host.screens[0].name === canvas.modelData.name
    readonly property var picked: canvas.host.find(canvas.host.selected)

    function key(event: var): void {
        const id = canvas.host.selected;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const steps = {
            [Qt.Key_Left]: [-1, 0],
            [Qt.Key_Right]: [1, 0],
            [Qt.Key_Up]: [0, -1],
            [Qt.Key_Down]: [0, 1]
        };
        event.accepted = true;
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            canvas.host.done();
        else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))
            canvas.host.undo();
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const list = canvas.ids;
            if (list.length > 0)
                canvas.host.selected = list[(list.indexOf(id) + (event.key === Qt.Key_Backtab ? list.length - 1 : 1)) % list.length];
        } else if (canvas.picked === null)
            event.accepted = false;
        else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
            canvas.host.remove(id);
        else if (steps[event.key] !== undefined) {
            const d = steps[event.key];
            canvas.host.change(shift ? {
                kind: "resize",
                id: id,
                w: canvas.picked.w + d[0],
                h: canvas.picked.h + d[1]
            } : {
                kind: "move",
                id: id,
                dc: d[0],
                dr: d[1]
            });
        } else
            event.accepted = false;
    }

    screen: canvas.modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Qt.rgba(0, 0, 0, 0.32)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sylwidget-edit"
    WlrLayershell.keyboardFocus: canvas.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => canvas.key(event)
        Component.onCompleted: keys.forceActiveFocus()
    }

    Canvas {
        id: dots
        anchors.fill: parent
        opacity: 0.35
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Theme.text;
            const step = canvas.cfg.cell + canvas.cfg.gap;
            for (let x = canvas.cfg.gap; x < width; x += step) {
                for (let y = canvas.cfg.gap; y < height; y += step)
                    ctx.fillRect(x - 1, y - 1, 2, 2);
            }
        }
    }

    TapHandler {
        onTapped: canvas.host.selected = ""
    }

    Repeater {
        model: canvas.ids

        delegate: Item {
            id: proxy

            required property string modelData
            readonly property var item: canvas.host.find(proxy.modelData)
            readonly property var rect: proxy.item === null ? null : Wd.place(proxy.item, canvas.here, canvas.cfg.cell, canvas.cfg.gap)
            readonly property bool picked: canvas.host.selected === proxy.modelData
            property real dx: 0
            property real dy: 0
            property real dw: 0
            property real dh: 0

            visible: proxy.rect !== null
            x: (proxy.rect === null ? 0 : proxy.rect.x) + proxy.dx
            y: (proxy.rect === null ? 0 : proxy.rect.y) + proxy.dy
            width: (proxy.rect === null ? 0 : proxy.rect.w) + proxy.dw
            height: (proxy.rect === null ? 0 : proxy.rect.h) + proxy.dh

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radiusCard
                color: Qt.alpha(Theme.accent, proxy.picked ? 0.16 : 0.06)
                border.width: proxy.picked ? 2 : 1
                border.color: proxy.picked ? Theme.accent : Qt.alpha(Theme.text, 0.5)
            }

            Rectangle {
                anchors.centerIn: parent
                width: tag.implicitWidth + 16
                height: tag.implicitHeight + 8
                radius: height / 2
                color: Theme.pane
            }

            Text {
                id: tag
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: proxy.item === null ? "" : Wd.TYPES[proxy.item.type].label + "  " + proxy.item.w + "×" + proxy.item.h
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
                font.weight: Font.DemiBold
            }

            DragHandler {
                id: move
                target: null
                onActiveTranslationChanged: {
                    if (move.active) {
                        proxy.dx = move.activeTranslation.x;
                        proxy.dy = move.activeTranslation.y;
                    }
                }
                onActiveChanged: {
                    if (move.active) {
                        canvas.host.selected = proxy.modelData;
                        return;
                    }
                    const g = canvas.cfg.gap;
                    canvas.host.change({
                        kind: "place",
                        id: proxy.modelData,
                        anchor: "top-left",
                        col: Wd.snap(proxy.x - g, canvas.cfg.cell, g),
                        row: Wd.snap(proxy.y - g, canvas.cfg.cell, g)
                    });
                    proxy.dx = 0;
                    proxy.dy = 0;
                }
            }

            TapHandler {
                onTapped: canvas.host.selected = proxy.modelData
            }

            Rectangle {
                width: 26
                height: 26
                radius: width / 2
                x: -8
                y: -8
                color: Theme.pane
                border.width: 1
                border.color: Theme.cardLine

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: "−"
                    color: Theme.text
                    font.pixelSize: Tokens.bodySize
                }

                TapHandler {
                    onTapped: canvas.host.remove(proxy.modelData)
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: width / 2
                x: parent.width - 12
                y: parent.height - 12
                color: Theme.accent

                DragHandler {
                    id: grow
                    target: null
                    onActiveTranslationChanged: {
                        if (grow.active) {
                            proxy.dw = grow.activeTranslation.x;
                            proxy.dh = grow.activeTranslation.y;
                        }
                    }
                    onActiveChanged: {
                        if (grow.active)
                            return;
                        const g = canvas.cfg.gap;
                        const step = canvas.cfg.cell + g;
                        canvas.host.change({
                            kind: "resize",
                            id: proxy.modelData,
                            w: Math.max(1, Math.round((proxy.width + g) / step)),
                            h: Math.max(1, Math.round((proxy.height + g) / step))
                        });
                        proxy.dw = 0;
                        proxy.dh = 0;
                    }
                }
            }
        }
    }

    Glass {
        id: bar
        visible: canvas.typing
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: row.implicitWidth + 32
        height: row.implicitHeight + 24
        radius: Tokens.radiusCard

        Column {
            id: row
            anchors.centerIn: parent
            spacing: 10

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drag to move, pull the dot to resize. Arrows move, Shift+arrows resize, Tab picks, Delete removes, Ctrl+Z undoes, Esc is done."
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: Object.keys(Wd.TYPES).filter(t => Wd.TYPES[t].plugin === undefined || Settings.values.plugins.enabled[Wd.TYPES[t].plugin] === true)

                    delegate: Chip {
                        required property string modelData
                        text: Wd.TYPES[modelData].label
                        glyph: Icons.GLYPHS[Wd.TYPES[modelData].glyph] || ""
                        onClicked: canvas.host.add(modelData)
                    }
                }

                Chip {
                    text: "Done"
                    lit: true
                    onClicked: canvas.host.done()
                }
            }
        }
    }
}
