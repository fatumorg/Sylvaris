import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FocusScope {
    id: pane

    required property var files
    readonly property bool grid: pane.files.cfg.view === "grid"
    readonly property real minCell: Math.max(104, pane.files.cfg.iconSize + 60)
    readonly property int cols: pane.grid ? Math.max(1, Math.floor(gridView.width / pane.minCell)) : 1
    readonly property var view: pane.grid ? gridView : listView
    readonly property real cellW: pane.grid ? gridView.cellWidth : listView.width
    readonly property real cellH: pane.grid ? gridView.cellHeight : 36
    readonly property int rows: Math.max(1, Math.floor(pane.view.height / pane.cellH))
    readonly property var columns: {
        const size = 96;
        const time = 150;
        const kind = Math.min(170, Math.max(110, listView.width * 0.16));
        return {
            name: Math.max(180, listView.width - 8 - size - time - kind),
            size: size,
            time: time,
            kind: kind
        };
    }
    property string typed: ""
    property point origin: Qt.point(0, 0)
    property point reach: Qt.point(0, 0)
    property bool banding: false
    property var keep: []
    property real arrival: 1

    activeFocusOnTab: true

    function scrollBy(dy: real, smooth: bool): void {
        const v = pane.view;
        const top = v.originY - v.topMargin;
        const bottom = Math.max(top, v.originY + v.contentHeight + v.bottomMargin - v.height);
        const from = glide.running ? glide.to : v.contentY;
        const to = Math.max(top, Math.min(bottom, from + dy));
        if (smooth) {
            glide.target = v;
            glide.to = to;
            glide.restart();
        } else {
            glide.stop();
            v.contentY = to;
        }
    }

    function hitsNow(): void {
        const v = pane.view;
        const hits = F.bandHits({
            x: pane.origin.x,
            y: pane.origin.y,
            w: pane.reach.x - pane.origin.x,
            h: pane.reach.y - pane.origin.y
        }, {
            cols: pane.cols,
            cellW: pane.cellW,
            cellH: pane.cellH,
            count: pane.files.items.length
        });
        pane.files.band(hits, pane.keep);
    }

    Connections {
        target: pane.files

        function onRevealed(i: int): void {
            if (i >= 0)
                pane.view.positionViewAtIndex(i, GridView.Contain);
        }

        function onFocusView(): void {
            pane.forceActiveFocus();
        }

        function onPathChanged(): void {
            glide.stop();
            arrive.restart();
        }
    }

    NumberAnimation {
        id: glide
        property: "contentY"
        duration: Math.round(Tokens.fadeDuration * 0.9)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    Keys.onPressed: event => {
        const nav = {
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_Home]: "home",
            [Qt.Key_End]: "end",
            [Qt.Key_PageUp]: "pageUp",
            [Qt.Key_PageDown]: "pageDown"
        }[event.key];
        if (nav !== undefined && !(event.modifiers & Qt.AltModifier)) {
            if (pane.grid || (nav !== "left" && nav !== "right"))
                pane.files.move(nav, event.modifiers, pane.cols, pane.rows);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            if (pane.files.query !== "")
                pane.files.search("");
            else if (pane.files.chooser && pane.files.selected.length === 0)
                pane.files.close();
            else
                pane.files.clearSelection();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier) {
            const i = pane.files.names.indexOf(pane.files.cursor);
            const cell = i >= 0 && pane.files.selection[pane.files.cursor] ? pane.view.itemAtIndex(i) : null;
            const p = cell !== null ? cell.mapToItem(null, cell.width / 2, cell.height * 0.75) : pane.mapToItem(null, pane.width / 2, pane.height / 3);
            pane.files.contextAt(cell !== null ? pane.files.cursor : "", p.x, p.y);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Space && event.modifiers & Qt.ControlModifier && pane.files.cursor !== "") {
            pane.files.pick(pane.files.cursor, "toggle");
            event.accepted = true;
            return;
        }
        if (pane.files.key(F.comboOf(event.key, event.modifiers))) {
            event.accepted = true;
            return;
        }
        const t = event.text;
        if (t.length === 1 && t >= " " && t !== "\u007f" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            if (pane.files.cfg.typing === "filter") {
                pane.files.search(pane.files.query + t);
                pane.files.focusFilter();
            } else {
                pane.typed += t;
                typeReset.restart();
                pane.files.jump(pane.typed);
            }
            event.accepted = true;
        }
    }

    Timer {
        id: typeReset
        interval: 900
        onTriggered: pane.typed = ""
    }

    Item {
        id: banner
        width: parent.width
        height: pane.files.inTrash ? 48 : 0
        visible: height > 0

        Glass {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 6
            radius: Tokens.radiusRow
            inner: true
            flowing: false
        }

        Text {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -3
            textFormat: Text.PlainText
            text: "Restore puts items back where they were. Deleting here is for good."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -3
            spacing: 8

            PillButton {
                label: "Restore"
                glyph: F.GLYPH.restore
                enabled: pane.files.selected.length > 0
                onClicked: pane.files.restoreSelected()
            }

            PillButton {
                label: "Empty trash"
                glyph: F.GLYPH.deleteForever
                danger: true
                enabled: pane.files.entries.length > 0
                onClicked: pane.files.dialog = "empty"
            }
        }
    }

    Item {
        id: header
        anchors.top: banner.bottom
        width: parent.width
        height: pane.grid ? 0 : 30
        visible: !pane.grid

        Repeater {
            model: [
                {
                    key: "name",
                    label: "Name",
                    x: 0,
                    w: pane.columns.name
                },
                {
                    key: "size",
                    label: "Size",
                    x: pane.columns.name,
                    w: pane.columns.size
                },
                {
                    key: "modified",
                    label: "Modified",
                    x: pane.columns.name + pane.columns.size,
                    w: pane.columns.time
                },
                {
                    key: "kind",
                    label: "Kind",
                    x: pane.columns.name + pane.columns.size + pane.columns.time,
                    w: pane.columns.kind
                }
            ]

            delegate: Item {
                id: col
                required property var modelData
                readonly property bool on: pane.files.cfg.sort === col.modelData.key
                x: col.modelData.x + 4
                width: col.modelData.w
                height: parent.height

                Glass {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 8
                    inner: true
                    flowing: false
                    hot: colArea.containsMouse
                    opacity: colArea.containsMouse ? 1 : 0
                }

                Row {
                    x: col.modelData.key === "size" ? parent.width - width - 12 : col.modelData.key === "name" ? 42 : 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        textFormat: Text.PlainText
                        text: col.modelData.label
                        color: col.on ? Theme.text : Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                    }

                    Glyph {
                        visible: col.on
                        text: pane.files.cfg.descending ? Icons.GLYPHS.chevronDown : Icons.GLYPHS.chevronUp
                        size: 12
                        color: Theme.accent
                    }
                }

                MouseArea {
                    id: colArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pane.files.sortBy(col.modelData.key)
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            x: 8
            width: parent.width - 16
            height: 1
            color: Qt.alpha(Theme.text, 0.08)
        }
    }

    Item {
        id: body
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            enabled: !pane.files.inTrash && pane.files.problem === ""
            onDropped: d => {
                const action = d.proposedAction === Qt.CopyAction || !(d.supportedActions & Qt.MoveAction) ? Qt.CopyAction : Qt.MoveAction;
                pane.files.dropped(pane.files.path, d.urls, action);
                d.accept(action);
            }
        }

        MouseArea {
            id: bandArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                pane.forceActiveFocus();
                pane.files.menu = null;
                if (pane.files.renaming !== "")
                    pane.files.cancelRename();
                if (mouse.button === Qt.RightButton)
                    return;
                const v = pane.view;
                const p = bandArea.mapToItem(v, mouse.x, mouse.y);
                pane.keep = mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier) ? pane.files.selected.slice() : [];
                if (pane.keep.length === 0)
                    pane.files.clearSelection();
                pane.origin = Qt.point(p.x + v.contentX, p.y + v.contentY);
                pane.reach = pane.origin;
                pane.banding = true;
            }
            onPositionChanged: mouse => {
                if (!pane.banding)
                    return;
                const v = pane.view;
                const p = bandArea.mapToItem(v, mouse.x, mouse.y);
                pane.reach = Qt.point(Math.max(0, Math.min(v.width - 1, p.x)) + v.contentX, p.y + v.contentY);
                pane.hitsNow();
                edgeScroll.dy = mouse.y < 24 ? -14 : mouse.y > height - 24 ? 14 : 0;
            }
            onReleased: {
                pane.banding = false;
                edgeScroll.dy = 0;
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    const p = bandArea.mapToItem(null, mouse.x, mouse.y);
                    pane.files.contextAt("", p.x, p.y);
                }
            }
        }

        Timer {
            id: edgeScroll
            property real dy: 0
            interval: 16
            repeat: true
            running: pane.banding && edgeScroll.dy !== 0
            onTriggered: {
                pane.scrollBy(edgeScroll.dy, false);
                pane.reach = Qt.point(pane.reach.x, pane.reach.y + edgeScroll.dy);
                pane.hitsNow();
            }
        }

        GridView {
            id: gridView
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 10
            visible: pane.grid
            interactive: false
            topMargin: 6
            bottomMargin: 12
            cacheBuffer: 600
            cellWidth: Math.floor(width / pane.cols)
            cellHeight: pane.files.cfg.iconSize + 70
            model: pane.grid ? pane.files.items : []
            opacity: pane.arrival
            transform: Translate {
                y: (1 - pane.arrival) * 10
            }

            delegate: FileTile {
                files: pane.files
                width: gridView.cellWidth
                height: gridView.cellHeight
            }
        }

        ListView {
            id: listView
            anchors.fill: parent
            anchors.rightMargin: 10
            visible: !pane.grid
            interactive: false
            topMargin: 4
            bottomMargin: 12
            cacheBuffer: 600
            model: pane.grid ? [] : pane.files.items
            opacity: pane.arrival
            transform: Translate {
                y: (1 - pane.arrival) * 10
            }

            delegate: FileRow {
                files: pane.files
                columns: pane.columns
                width: listView.width
                height: 36
            }
        }

        Rectangle {
            visible: pane.banding
            x: Math.min(pane.origin.x, pane.reach.x) - pane.view.contentX + pane.view.x
            y: Math.min(pane.origin.y, pane.reach.y) - pane.view.contentY + pane.view.y
            width: Math.abs(pane.reach.x - pane.origin.x)
            height: Math.abs(pane.reach.y - pane.origin.y)
            radius: 6
            color: Qt.alpha(Theme.accent, 0.14)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.7)
        }

        Item {
            id: rail
            anchors.right: parent.right
            anchors.rightMargin: 2
            y: 6
            width: 8
            height: parent.height - 12
            readonly property real span: pane.view.contentHeight + pane.view.topMargin + pane.view.bottomMargin
            readonly property real share: rail.span > 0 ? Math.min(1, pane.view.height / rail.span) : 1
            visible: rail.share < 1
            opacity: railArea.containsMouse || railArea.pressed || glide.running ? 1 : 0.55

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.fadeDuration
                }
            }

            Rectangle {
                id: thumb
                width: railArea.containsMouse || railArea.pressed ? 8 : 5
                anchors.right: parent.right
                radius: width / 2
                height: Math.max(36, rail.height * rail.share)
                y: (rail.height - thumb.height) * Math.max(0, Math.min(1, (pane.view.contentY + pane.view.topMargin) / Math.max(1, rail.span - pane.view.height)))
                color: railArea.pressed ? Theme.accent : Qt.alpha(Theme.text, 0.35)

                Behavior on width {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            MouseArea {
                id: railArea
                anchors.fill: parent
                anchors.leftMargin: -6
                hoverEnabled: true
                preventStealing: true
                function follow(y: real): void {
                    const f = Math.max(0, Math.min(1, (y - thumb.height / 2) / Math.max(1, rail.height - thumb.height)));
                    pane.view.contentY = f * Math.max(0, rail.span - pane.view.height) - pane.view.topMargin;
                }
                onPressed: mouse => follow(mouse.y)
                onPositionChanged: mouse => {
                    if (pressed)
                        follow(mouse.y);
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.angleDelta.y !== 0)
                        pane.files.zoom(event.angleDelta.y > 0 ? 1 : -1);
                    return;
                }
                if (event.pixelDelta.y !== 0)
                    pane.scrollBy(-event.pixelDelta.y, false);
                else
                    pane.scrollBy(-event.angleDelta.y / 120 * Math.max(60, pane.cellH * 0.75), true);
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10
            width: Math.min(parent.width - 48, 420)
            visible: opacity > 0
            opacity: pane.files.items.length === 0 && (pane.files.problem !== "" || pane.arrival > 0.99) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.fadeDuration
                }
            }

            QtObject {
                id: empty
                readonly property string kind: pane.files.problem !== "" ? pane.files.problem : pane.files.query !== "" ? "query" : pane.files.entries.length > 0 ? "hidden" : pane.files.inTrash ? "trash" : pane.files.inArchive ? "inside" : "empty"
            }

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                text: empty.kind === "denied" || empty.kind === "locked" ? F.GLYPH.lock : empty.kind === "missing" || empty.kind === "broken" ? F.GLYPH.alert : empty.kind === "loading" || empty.kind === "inside" ? F.GLYPH.archive : empty.kind === "query" ? Icons.GLYPHS.search : empty.kind === "trash" ? F.GLYPH.trash : empty.kind === "hidden" ? F.GLYPH.eyeOff : F.GLYPH.folderOpen
                size: 56
                color: Qt.alpha(Theme.accent, 0.8)
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: ({
                        denied: "You cannot open this folder",
                        missing: "This folder is not there",
                        query: "Nothing here matches “" + pane.files.query + "”",
                        hidden: "Only hidden files here",
                        trash: "The trash is empty",
                        empty: "This folder is empty",
                        loading: "Opening the archive…",
                        broken: "This archive cannot be read",
                        locked: "This archive has a password",
                        inside: "Nothing in here"
                    })[empty.kind]
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.titleSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: ({
                        denied: "Your user has no permission to look inside.",
                        missing: "It may have been moved, renamed or unmounted.",
                        query: "Esc clears the filter.",
                        hidden: "Press " + F.keyText((pane.files.keys.byAction.hidden || [""])[0]) + " to show them.",
                        trash: "Things you delete wait here until you empty it.",
                        empty: "Drop files here, or press " + F.keyText((pane.files.keys.byAction.newFolder || [""])[0]) + " for a new folder.",
                        loading: "Big archives take a moment.",
                        broken: pane.files.problemText || "It may be damaged or only partly downloaded.",
                        locked: "Type the password to see what is inside.",
                        inside: pane.files.canChange ? "Drop files here to add them." : "This kind of archive can only be read."
                    })[empty.kind]
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
                wrapMode: Text.Wrap
            }

            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: empty.kind === "locked"
                label: "Type the password"
                glyph: F.GLYPH.lock
                primary: true
                onClicked: pane.files.askPassword(false, null)
            }
        }
    }

    NumberAnimation {
        id: arrive
        target: pane
        property: "arrival"
        from: 0
        to: 1
        duration: Tokens.fadeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }
}
