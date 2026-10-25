import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Item {
    id: side

    required property var files

    Glass {
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 0
        radius: Tokens.radiusCard
        inner: true
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 0
        contentHeight: col.height + 16
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            y: 8
            x: 8
            width: flick.width - 16
            spacing: 2

            Repeater {
                model: side.files.cfg.sections.map(k => ({ key: k, title: ({ places: "Places", bookmarks: "Bookmarks", devices: "Devices" })[k] }))

                delegate: Column {
                    id: section
                    required property var modelData
                    required property int index
                    readonly property var rows: side.files.sidebar.filter(x => x.section === section.modelData.key)
                    width: col.width
                    spacing: 2

                    Text {
                        x: 10
                        topPadding: section.index === 0 ? 4 : 14
                        bottomPadding: 4
                        textFormat: Text.PlainText
                        text: section.modelData.title
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.7
                    }

                    Text {
                        visible: section.rows.length === 0
                        x: 10
                        width: parent.width - 20
                        bottomPadding: 4
                        textFormat: Text.PlainText
                        text: "Press " + F.keyText((side.files.keys.byAction.bookmark || [""])[0]) + " to keep a folder here."
                        wrapMode: Text.Wrap
                        color: Qt.alpha(Theme.textDim, 0.8)
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }

                    Repeater {
                        model: section.rows

                        delegate: Item {
                            id: place
                            required property var modelData
                            readonly property var drive: place.modelData.drive
                            readonly property bool waiting: place.drive !== null && side.files.driveBusy === place.drive.id
                            readonly property bool away: place.drive !== null && (!place.drive.mounted || place.drive.locked)
                            readonly property bool ejects: place.drive !== null && !place.drive.locked && (place.drive.mounted || place.drive.drive !== "")
                            readonly property bool hot: area.containsMouse
                            width: section.width
                            height: 34

                            Glass {
                                anchors.fill: parent
                                radius: 10
                                inner: true
                                flowing: false
                                hot: place.hot || drop.containsDrag
                                lit: place.modelData.active || drop.containsDrag
                                opacity: place.modelData.active || place.hot || drop.containsDrag ? 1 : 0
                                offColor: place.hot ? Theme.tintMid : Theme.tintSoft

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }
                            }

                            Glyph {
                                id: mark
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: place.modelData.glyph
                                size: 17
                                color: place.modelData.active ? Theme.onAccent : Theme.accent
                                opacity: place.away && !place.hot ? 0.55 : 1

                                SequentialAnimation on opacity {
                                    running: place.waiting && Tokens.fadeDuration > 0
                                    loops: Animation.Infinite
                                    alwaysRunToEnd: true

                                    NumberAnimation {
                                        to: 0.25
                                        duration: Tokens.fadeDuration * 2
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        to: 1
                                        duration: Tokens.fadeDuration * 2
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }

                            Text {
                                anchors.left: mark.right
                                anchors.leftMargin: 10
                                anchors.right: remove.visible ? remove.left : eject.visible ? eject.left : parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.PlainText
                                text: place.modelData.label
                                elide: Text.ElideRight
                                color: place.modelData.active ? Theme.onAccent : place.away ? Theme.textSoft : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.smallSize
                                font.weight: place.modelData.active ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (place.drive !== null) {
                                            const p = area.mapToItem(null, mouse.x, mouse.y);
                                            side.files.contextDrive(place.drive.id, p.x, p.y);
                                        }
                                    } else if (place.drive !== null) {
                                        side.files.openDrive(place.drive, mouse.button === Qt.MiddleButton);
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        side.files.newTab(place.modelData.path);
                                    } else {
                                        side.files.go(place.modelData.path);
                                    }
                                }
                            }

                            Glyph {
                                id: remove
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                visible: place.modelData.own && (place.hot || removeArea.containsMouse)
                                text: Icons.GLYPHS.close
                                size: 13
                                color: removeArea.containsMouse ? Theme.danger : (place.modelData.active ? Theme.onAccent : Theme.textDim)

                                MouseArea {
                                    id: removeArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: side.files.toggleBookmark(place.modelData.path)
                                }
                            }

                            Glyph {
                                id: eject
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                visible: place.ejects && !place.waiting
                                text: F.GLYPH.eject
                                size: 15
                                color: ejectArea.containsMouse ? (place.modelData.active ? Theme.onAccent : Theme.text) : (place.modelData.active ? Qt.alpha(Theme.onAccent, 0.8) : Theme.textDim)
                                scale: ejectArea.pressed ? 0.85 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }

                                MouseArea {
                                    id: ejectArea
                                    anchors.fill: parent
                                    anchors.margins: -7
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: side.files.ejectDrive(place.drive)
                                }
                            }

                            DropArea {
                                id: drop
                                enabled: place.modelData.path !== ""
                                anchors.fill: parent
                                keys: ["text/uri-list"]
                                onDropped: d => {
                                    const action = d.proposedAction === Qt.CopyAction || !(d.supportedActions & Qt.MoveAction) ? Qt.CopyAction : Qt.MoveAction;
                                    side.files.dropped(place.modelData.path, d.urls, action);
                                    d.accept(action);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
