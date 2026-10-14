import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Item {
    id: status

    required property var files
    readonly property bool working: status.files.job !== null
    readonly property real share: status.files.total > 0 ? status.files.done / status.files.total : 0

    Text {
        id: count
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: F.summary(status.files.items, status.files.selected)
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
        font.features: {
            "tnum": 1
        }
    }

    Row {
        id: middle
        anchors.centerIn: parent
        spacing: 10
        visible: status.working || status.files.note !== ""

        Item {
            visible: status.working
            width: 150
            height: 6
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Qt.alpha(Theme.text, 0.12)
            }

            Rectangle {
                width: status.files.total > 0 ? parent.width * status.share : parent.width * 0.3
                x: status.files.total > 0 ? 0 : (parent.width - width) * (0.5 + 0.5 * Math.sin(sweep.t))
                height: parent.height
                radius: 3
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            FrameAnimation {
                id: sweep
                property real t: 0
                running: status.working && status.files.total === 0
                onTriggered: sweep.t += frameTime * 3
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: status.working ? ({
                        copy: "Copying",
                        move: "Moving",
                        rename: "Renaming",
                        trash: "Moving to the trash",
                        delete: "Deleting",
                        mkdir: "Creating",
                        touch: "Creating",
                        restore: "Restoring",
                        untrash: "Restoring",
                        empty: "Emptying the trash"
                    })[status.files.job.kind] + (status.files.total > 0 ? " · " + F.sizeText(status.files.done) + " of " + F.sizeText(status.files.total) : "…") + (status.files.queue.length > 0 ? " · " + status.files.queue.length + " waiting" : "") : status.files.note
            color: Theme.text
            elide: Text.ElideRight
            width: Math.min(implicitWidth, status.width - count.width - free.width - 260)
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }

        Text {
            visible: !status.working && status.files.noteUndo
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Undo"
            color: undoArea.containsMouse ? Theme.accentHi : Theme.accent
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
            font.weight: Font.DemiBold
            font.underline: undoArea.containsMouse

            MouseArea {
                id: undoArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: status.files.undo()
            }
        }

        Glyph {
            visible: status.working && ["copy", "move"].indexOf(status.files.job.kind) >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.GLYPHS.close
            size: 12
            color: stopArea.containsMouse ? Theme.danger : Theme.textDim

            MouseArea {
                id: stopArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: status.files.cancelJob()
            }
        }
    }

    Text {
        id: free
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: status.files.free >= 0 ? F.sizeText(status.files.free) + " free" : ""
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
    }
}
