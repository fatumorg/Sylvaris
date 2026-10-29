import QtQuick
import qs
import qs.services
import qs.components
import "../lib/island.mjs" as I
import "../lib/icons.mjs" as Icons
import "../lib/capture.mjs" as C

Item {
    id: root

    property var items: []
    property var shortcuts: []
    property bool expanded: false
    property bool atTop: true
    property string idle: "pill"
    property string time: ""
    property int replying: -1
    property real progress: 0
    property real position: 0
    property real length: 0
    property int unread: 0
    property bool quiet: false
    readonly property string kindKey: root.items.map(a => a.kind).join(",")
    readonly property var kinds: root.kindKey === "" ? [] : root.kindKey.split(",")
    readonly property string shortcutKey: root.shortcuts.map(s => s.id).join(",")
    readonly property var shortcutIds: root.shortcutKey === "" ? [] : root.shortcutKey.split(",")
    readonly property var main: root.items.length > 0 ? root.items[0] : null
    readonly property var second: root.items.length > 1 ? root.items[1] : null
    readonly property bool shown: root.main !== null || root.idle !== "hide"
    readonly property real pillHeight: 38
    readonly property real cardWidth: 380
    readonly property real cardHeight: I.cardHeight(root.kinds, root.shortcutIds.length > 0)
    readonly property bool open: root.expanded && root.cardHeight > 0
    readonly property real compactWidth: root.main !== null ? Math.min(360, compactRow.implicitWidth + 28) : Math.max(root.idle === "clock" ? 0 : 104, idleRow.implicitWidth + 32)
    readonly property real bodyWidth: root.open ? root.cardWidth : root.compactWidth
    readonly property real bodyHeight: root.open ? root.cardHeight : root.pillHeight
    readonly property bool bubble: root.second !== null && !root.open
    readonly property bool calm: Tokens.paused || Tokens.motion < 0.05
    readonly property Item pill: body
    readonly property Item side: bubbleItem

    signal act(string kind, string what)
    signal run(string id)
    signal pin
    signal wheel(int steps)

    implicitWidth: body.width + (root.bubble ? root.pillHeight + 8 : 0)
    implicitHeight: body.height
    opacity: root.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    function find(kind: string): var {
        for (const a of root.items) {
            if (a.kind === kind)
                return a;
        }
        return null;
    }

    function glyphOf(a: var): string {
        if (a === null)
            return "";
        switch (a.kind) {
        case "volume":
            return a.muted || a.value <= 0 ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume;
        case "notification":
            return Icons.GLYPHS.bell;
        case "message":
            return Icons.GLYPHS.speech;
        case "call":
            return Icons.GLYPHS.voice;
        case "voice":
            return a.muted ? Icons.GLYPHS.micOff : Icons.GLYPHS.mic;
        case "device":
            return a.audio ? Icons.GLYPHS.headphones : Icons.GLYPHS.bluetooth;
        case "recording":
            return Icons.GLYPHS.record;
        case "alarm":
            return Icons.GLYPHS.alarm;
        case "focus":
            return Icons.GLYPHS.timer;
        case "next":
            return Icons.GLYPHS.planner;
        case "custom":
            return Icons.GLYPHS.info;
        case "privacy":
            return Icons.GLYPHS.micOff;
        case "inuse":
            return a.camera ? Icons.GLYPHS.camera : Icons.GLYPHS.mic;
        case "status":
            return Icons.GLYPHS[a.glyph] || Icons.GLYPHS.info;
        default:
            return Icons.GLYPHS.musicNote;
        }
    }

    function tintOf(a: var): color {
        return a !== null && (a.kind === "recording" || a.kind === "alarm" || a.kind === "privacy" || a.kind === "voice" && a.muted) ? Theme.danger : Theme.accent;
    }

    function headOf(a: var): string {
        if (a === null)
            return "";
        switch (a.kind) {
        case "volume":
            return "Volume";
        case "notification":
            return a.summary || a.app;
        case "message":
        case "call":
            return a.sender || a.app;
        case "voice":
            return a.app;
        case "device":
            return a.name;
        case "recording":
            return a.started ? "Recording" : "Recording soon";
        case "alarm":
        case "focus":
            return a.title;
        case "next":
        case "custom":
        case "status":
            return a.text;
        case "privacy":
            return "Mic and cameras off";
        case "inuse":
            return a.apps.join(", ");
        default:
            return a.title || a.artist;
        }
    }

    function subOf(a: var): string {
        if (a === null)
            return "";
        switch (a.kind) {
        case "volume":
        case "recording":
            return I.label(a);
        case "notification":
            return a.body || a.app;
        case "message":
            return a.app + (a.more > 0 ? " · +" + a.more : "") + (a.text ? " · " + a.text : "");
        case "call":
            return a.app + " · incoming call";
        case "voice":
            return a.muted ? "Voice chat · microphone muted" : "Voice chat · " + I.label(a).split(" · ")[1];
        case "device":
            return a.battery >= 0 ? "Connected · " + a.battery + "% battery" : "Connected";
        case "alarm":
            return "Diver alarm";
        case "focus":
            return "Focus · " + I.label(a) + " left";
        case "next":
            return "Starts " + I.label(a);
        case "custom":
            return "Sylvaris";
        case "status":
            return a.state;
        case "privacy":
            return a.combo !== "" ? "Privacy mode · " + a.combo + " to undo" : "Privacy mode";
        case "inuse":
            return "Using the " + (a.mic && a.camera ? "microphone and camera" : a.camera ? "camera" : "microphone");
        default:
            return a.artist || a.player || "";
        }
    }

    function actionsOf(kind: string, a: var): var {
        if (kind === "message")
            return (a !== null && a.reply ? ["reply"] : []).concat(a !== null && a.read !== "" ? ["read"] : [], ["openapp", "dismiss"]);
        if (kind === "call")
            return ["decline", "accept"];
        if (kind === "voice")
            return ["mute", "openapp"];
        return ({
                media: ["previous", "toggle", "next"],
                recording: ["stop"],
                alarm: ["snooze", "done"],
                focus: ["end"],
                volume: ["mute"],
                notification: ["dismiss"],
                privacy: ["undo"],
                inuse: ["block"]
            })[kind] || [];
    }

    function actionGlyph(id: string, a: var): string {
        switch (id) {
        case "previous":
            return Icons.GLYPHS.previous;
        case "next":
            return Icons.GLYPHS.next;
        case "toggle":
            return a !== null && a.playing ? Icons.GLYPHS.pause : Icons.GLYPHS.play;
        case "stop":
            return Icons.GLYPHS.stopCircle;
        case "snooze":
            return Icons.GLYPHS.sleep;
        case "done":
            return Icons.GLYPHS.check;
        case "mute":
            if (a !== null && a.kind === "voice")
                return a.muted ? Icons.GLYPHS.micOff : Icons.GLYPHS.mic;
            return a !== null && a.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume;
        case "reply":
            return Icons.GLYPHS.pencil;
        case "read":
            return Icons.GLYPHS.eye;
        case "openapp":
            return Icons.GLYPHS.open;
        case "undo":
            return Icons.GLYPHS.mic;
        case "block":
            return Icons.GLYPHS.micOff;
        case "accept":
            return Icons.GLYPHS.voice;
        default:
            return Icons.GLYPHS.close;
        }
    }

    component Lead: Item {
        id: lead

        property var a: null
        property real size: 24

        width: lead.size
        height: lead.size

        Rectangle {
            anchors.fill: parent
            visible: !artImage.visible
            radius: lead.size >= 40 ? 14 : lead.size / 2
            color: Qt.alpha(root.tintOf(lead.a), 0.16)
            border.width: 1
            border.color: Qt.alpha(root.tintOf(lead.a), 0.22)
        }

        RoundImage {
            id: artImage
            anchors.fill: parent
            visible: lead.a !== null && lead.a.art !== undefined && lead.a.art !== ""
            source: visible ? lead.a.art : ""
            radius: lead.size >= 40 ? 14 : lead.size / 2
            fallbackColor: Theme.accentDeep
        }

        Rectangle {
            anchors.centerIn: parent
            visible: lead.a !== null && lead.a.kind === "recording"
            width: lead.size * 0.42
            height: width
            radius: width / 2
            color: Theme.danger

            SequentialAnimation on opacity {
                running: lead.visible && lead.a !== null && lead.a.kind === "recording" && !root.calm
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.3
                    duration: Tokens.loopMs(700)
                }
                NumberAnimation {
                    to: 1
                    duration: Tokens.loopMs(700)
                }
            }
        }

        Glyph {
            anchors.centerIn: parent
            visible: !artImage.visible && lead.a !== null && lead.a.kind !== "recording"
            text: root.glyphOf(lead.a)
            size: lead.size * (lead.size >= 40 ? 0.5 : 0.62)
            color: root.tintOf(lead.a)
        }
    }

    component Bars: Row {
        id: bars

        property bool live: false

        spacing: 2
        height: 14

        Repeater {
            model: 4

            Rectangle {
                id: bar

                required property int index
                property real level: 0.25 + 0.18 * bar.index

                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                height: bars.height * bar.level
                color: Theme.accent

                SequentialAnimation on level {
                    running: bars.live && !root.calm
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 1
                        duration: Tokens.loopMs(260 + bar.index * 90)
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0.25 + 0.1 * bar.index
                        duration: Tokens.loopMs(300 + bar.index * 70)
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    component Press: Item {
        id: press

        property string glyph: ""
        property bool strong: false
        property bool lit: false
        property bool danger: false
        property int badge: 0
        property string tip: ""
        property bool square: false

        signal clicked

        width: press.square ? 40 : 34
        height: 34
        opacity: press.enabled ? 1 : 0.4
        scale: area.pressed ? 0.9 : 1
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: press.tip

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.stateDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.enterCurve
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: press.square ? 12 : width / 2
            color: press.danger ? (area.pressed ? Qt.darker(Theme.danger, 1.2) : Theme.danger) : press.strong ? (area.pressed ? Qt.darker(Theme.accent, 1.15) : area.containsMouse ? Theme.accentHi : Theme.accent) : press.lit ? Qt.alpha(Theme.accent, area.pressed ? 0.45 : area.containsMouse ? 0.35 : 0.26) : area.pressed ? Qt.alpha(Theme.text, 0.18) : area.containsMouse || press.activeFocus ? Qt.alpha(Theme.text, 0.1) : press.square ? Qt.alpha(Theme.text, 0.05) : "transparent"
            border.width: press.activeFocus ? 1 : 0
            border.color: Theme.accent

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }

        Glyph {
            anchors.centerIn: parent
            text: press.glyph
            size: 18
            color: press.strong || press.danger ? Theme.onAccent : press.lit ? Theme.accent : Theme.text
        }

        Rectangle {
            visible: press.badge > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: press.square ? -3 : 0
            anchors.topMargin: press.square ? -3 : 0
            width: Math.max(16, badgeText.implicitWidth + 8)
            height: 16
            radius: Tokens.r(8)
            color: Theme.accent

            Text {
                textFormat: Text.PlainText
                id: badgeText
                anchors.centerIn: parent
                text: press.badge > 99 ? "99+" : String(press.badge)
                color: Theme.onAccent
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.tinySize - 2
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: press.clicked()
        }

        Keys.onReturnPressed: press.clicked()
        Keys.onSpacePressed: press.clicked()
    }

    component ActivityRow: Item {
        id: row

        required property string modelData
        readonly property var a: root.find(row.modelData)
        readonly property bool bar: row.modelData === "media" || row.modelData === "volume"
        readonly property string actionKey: root.actionsOf(row.modelData, row.a).join(",")
        readonly property bool typing: row.a !== null && row.a.id === root.replying && row.modelData === "message"
        readonly property bool big: row.modelData === "media"

        width: root.cardWidth - 24
        height: I.rowHeight(row.modelData)

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusRow
            color: rowArea.pressed ? Qt.alpha(Theme.text, 0.12) : rowArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : Qt.alpha(Theme.text, 0.04)
            border.width: 1
            border.color: Qt.alpha(Theme.text, rowArea.containsMouse ? 0.08 : 0.04)

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.act(row.modelData, "open")
        }

        Lead {
            id: rowLead
            x: 10
            y: 10
            a: row.a
            size: row.big ? 56 : 44
        }

        TextBox {
            id: replyBox
            visible: row.typing
            anchors.left: rowLead.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: rowLead.verticalCenter
            placeholder: row.a !== null && row.a.placeholder ? row.a.placeholder : ""
            onAccepted: root.act("message", "send:" + replyBox.text)
            onVisibleChanged: {
                if (visible) {
                    replyBox.text = "";
                    replyBox.focusInput();
                }
            }
            Keys.onEscapePressed: root.act("message", "cancel")
        }

        Column {
            visible: !row.typing
            anchors.left: rowLead.right
            anchors.leftMargin: 12
            anchors.right: rowActions.left
            anchors.rightMargin: 6
            y: rowLead.y + (rowLead.height - height) / 2
            spacing: 3

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.headOf(row.a)
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.subOf(row.a)
                elide: Text.ElideRight
                color: Theme.textDim
                font.family: row.modelData === "recording" || row.modelData === "volume" || row.modelData === "focus" ? Tokens.fontMono : Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }

        Row {
            id: rowActions
            visible: !row.typing
            anchors.right: parent.right
            anchors.rightMargin: 8
            y: rowLead.y + (rowLead.height - height) / 2
            spacing: 4

            Repeater {
                model: row.actionKey === "" ? [] : row.actionKey.split(",")

                Press {
                    required property string modelData
                    glyph: root.actionGlyph(modelData, row.a)
                    tip: modelData
                    danger: modelData === "decline" || modelData === "stop"
                    strong: modelData === "toggle" || modelData === "done" || modelData === "stop" || modelData === "accept"
                    onClicked: root.act(row.modelData, modelData)
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: row.big && root.length > 0
            x: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: C.elapsed(root.position * 1000)
            color: Theme.textDim
            font.family: Tokens.fontMono
            font.pixelSize: Tokens.tinySize - 1
        }

        Text {
            textFormat: Text.PlainText
            visible: row.big && root.length > 0
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: "-" + C.elapsed(Math.max(0, root.length - root.position) * 1000)
            color: Theme.textDim
            font.family: Tokens.fontMono
            font.pixelSize: Tokens.tinySize - 1
        }

        Rectangle {
            visible: row.bar
            x: row.big && root.length > 0 ? 52 : 10
            width: parent.width - 2 * x
            anchors.bottom: parent.bottom
            anchors.bottomMargin: row.big ? 13 : 12
            height: 4
            radius: Tokens.r(2)
            color: Qt.alpha(Theme.text, 0.14)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, row.a === null ? 0 : row.modelData === "volume" ? row.a.value : root.progress))
                height: parent.height
                radius: Tokens.r(2)
                color: row.a !== null && row.a.muted ? Theme.textDim : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: e => root.act(row.modelData, "seek:" + Math.max(0, Math.min(1, (e.x - 8) / (width - 16))))
            }
        }
    }

    Item {
        id: body
        width: root.bodyWidth
        height: root.bodyHeight
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }

        Glass {
            role: "island"
            anchors.fill: parent
            radius: Math.min(height / 2, Tokens.radiusPanel)
            raised: true
            flowing: false
            offColor: Theme.surface
            offBorder: Theme.line
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: e => {
                if (e.button === Qt.RightButton && root.main !== null)
                    root.act(root.main.kind, "open");
                else
                    root.pin();
            }
            onWheel: e => root.wheel(e.angleDelta.y > 0 ? 1 : e.angleDelta.y < 0 ? -1 : 0)
        }

        Item {
            width: root.compactWidth
            height: root.pillHeight
            y: root.atTop ? 0 : body.height - root.pillHeight
            opacity: root.open ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.fadeDuration
                }
            }

            Row {
                id: compactRow
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: root.main !== null
                spacing: 10

                Lead {
                    anchors.verticalCenter: parent.verticalCenter
                    a: root.main
                    size: 22
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 200)
                    text: root.main !== null ? I.label(root.main) : ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: root.main !== null && ["recording", "focus", "volume"].indexOf(root.main.kind) >= 0 ? Tokens.fontMono : Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    width: Math.min(implicitWidth, 110)
                    text: root.main !== null && root.main.kind === "media" && root.main.title && root.main.artist ? root.main.artist : ""
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Bars {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.main !== null && root.main.kind === "media"
                    live: visible && root.shown && !root.open && root.main.playing === true
                }
            }

            Rectangle {
                visible: root.main !== null && root.main.kind === "media" && root.length > 0
                x: 24
                y: root.atTop ? parent.height - 4 : 2
                width: parent.width - 48
                height: 2
                radius: Tokens.r(1)
                color: Qt.alpha(Theme.text, 0.12)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.progress))
                    height: parent.height
                    radius: Tokens.r(1)
                    color: Theme.accent
                }
            }

            Row {
                id: idleRow
                anchors.centerIn: parent
                visible: root.main === null
                spacing: 10

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.idle === "clock"
                    text: root.time
                    color: Theme.text
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.quiet
                    text: Icons.GLYPHS.dnd
                    size: 15
                    color: Theme.textDim
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.unread > 0
                    spacing: 4

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS.bell
                        size: 15
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.unread > 99 ? "99+" : String(root.unread)
                        color: Theme.text
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.tinySize
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.idle !== "clock" && !root.quiet && root.unread === 0
                    width: 28
                    height: 4
                    radius: Tokens.r(2)
                    color: Qt.alpha(Theme.text, 0.35)
                }
            }
        }

        Column {
            x: 12
            y: 12
            width: root.cardWidth - 24
            spacing: 6
            opacity: root.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.fadeDuration
                }
            }

            Repeater {
                model: root.kinds

                ActivityRow {}
            }

            Divider {
                visible: root.shortcutIds.length > 0 && root.kinds.length > 0
                x: 6
                width: parent.width - 12
            }

            Row {
                visible: root.shortcutIds.length > 0
                width: parent.width
                height: root.kinds.length > 0 ? 45 : 52
                topPadding: root.kinds.length > 0 ? 5 : 9
                readonly property int count: root.shortcutIds.length
                spacing: Math.min(10, Math.max(0, (width - count * 40) / Math.max(1, count - 1)))
                leftPadding: Math.max(0, (width - count * 40 - (count - 1) * spacing) / 2)

                Repeater {
                    model: root.shortcutIds

                    Press {
                        required property string modelData
                        readonly property var s: root.shortcuts.find(x => x.id === modelData) || null
                        square: true
                        glyph: s !== null ? Icons.GLYPHS[s.glyph] : ""
                        tip: s !== null ? s.label : ""
                        lit: s !== null && s.lit === true
                        badge: s !== null && s.badge !== undefined ? s.badge : 0
                        onClicked: root.run(modelData)
                    }
                }
            }
        }
    }

    Item {
        id: bubbleItem
        x: body.width + 8
        y: root.atTop ? 0 : body.height - root.pillHeight
        width: root.pillHeight
        height: root.pillHeight
        opacity: root.bubble ? 1 : 0
        scale: root.bubble ? 1 : 0.6
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.fadeDuration
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }

        Glass {
            anchors.fill: parent
            radius: height / 2
            raised: true
            flowing: false
            offColor: Theme.surface
            offBorder: Theme.line
        }

        Lead {
            anchors.centerIn: parent
            a: root.second
            size: 22
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pin()
        }
    }
}
