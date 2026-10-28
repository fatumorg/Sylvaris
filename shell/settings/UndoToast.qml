import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/settingsIndex.mjs" as X

Item {
    id: root

    readonly property var change: Settings.lastChange
    readonly property var entry: root.change === null ? null : X.INDEX.find(e => e.key === root.change.key) || null
    property bool live: false

    implicitWidth: row.implicitWidth + 36
    implicitHeight: 52
    opacity: root.live ? 1 : 0
    visible: root.opacity > 0
    scale: 0.94 + 0.06 * root.opacity

    onChangeChanged: {
        root.live = root.change !== null;
        if (root.live)
            hide.restart();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.stateDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    Timer {
        id: hide
        interval: 6000
        onTriggered: root.live = false
    }

    Glass {
        anchors.fill: parent
        radius: height / 2
        raised: true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: root.change === null ? "" : (root.change.reset ? "Reset " : "Changed ") + (root.entry !== null ? root.entry.title.toLowerCase() : root.change.key)
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
        }

        Chip {
            anchors.verticalCenter: parent.verticalCenter
            text: "Undo"
            glyph: Icons.GLYPHS.undo
            onClicked: {
                Settings.undo();
                root.live = false;
            }
        }
    }
}
