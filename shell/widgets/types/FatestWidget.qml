import QtQuick
import qs
import qs.services
import qs.components
import "../../lib/fatest.mjs" as F
import "../../lib/icons.mjs" as Icons

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property color accent: root.frame !== null ? root.frame.accent : Theme.accent
    property var st: null
    property var last: null
    readonly property bool running: root.st !== null && root.st.running
    readonly property string extra: root.last === null ? "" : [root.o.upload !== false ? "↑ " + F.speed(root.last.upload) : "", root.o.ping !== false ? Math.round(root.last.ping) + " ms" : ""].filter(s => s !== "").join(" · ")

    function read(words: var): var {
        const out = Ipc.run(words);
        if (out.indexOf("error") === 0)
            return null;
        try {
            return JSON.parse(out);
        } catch (e) {
            return null;
        }
    }

    function poll(): void {
        root.st = root.read(["fatest", "state"]);
        const h = root.read(["fatest", "history"]);
        root.last = Array.isArray(h) && h.length > 0 ? h[0] : null;
    }

    Timer {
        interval: root.running ? 500 : 5000
        running: root.visible && !(root.frame !== null && root.frame.paused)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    Column {
        anchors.left: parent.left
        anchors.right: button.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: root.running ? (root.st.phase === "upload" ? "Upload" : root.st.phase === "download" ? "Download" : "Starting…") : root.last === null ? "No tests yet" : "Last test"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            visible: root.running || root.last !== null
            text: root.running ? F.speed(root.st.phase === "upload" ? root.st.upload : root.st.download) : root.last === null ? "" : F.speed(root.last.download)
            color: Theme.text
            font.family: Tokens.fontDisplay
            font.pixelSize: Math.min(30, root.height * 0.3)
            font.weight: Font.DemiBold
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            visible: !root.running && root.extra !== ""
            text: root.extra
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    Rectangle {
        id: button
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(44, root.height * 0.5)
        height: width
        radius: width / 2
        color: tap.pressed ? Qt.darker(root.accent, 1.2) : root.accent

        Glyph {
            anchors.centerIn: parent
            text: root.running ? Icons.GLYPHS.close : Icons.GLYPHS.play
            color: Theme.onAccent
            size: parent.width * 0.45
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap
            onTapped: {
                Ipc.run(["fatest", root.running ? "stop" : "run"]);
                root.poll();
            }
        }
    }
}
