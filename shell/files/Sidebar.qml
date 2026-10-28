import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Item {
    id: side

    required property var files
    readonly property int ownCount: side.files.sidebar.filter(x => x.own).length
    readonly property int markCount: side.files.sidebar.filter(x => x.section === "bookmarks").length
    property string dragSection: ""
    property int dragFrom: -1
    property int dragTo: -1
    property real dragY: 0

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
                model: F.SECTIONS.length

                delegate: Column {
                    id: section
                    required property int index
                    readonly property string key: side.files.cfg.sections[section.index]
                    readonly property var rows: side.files.sidebar.filter(x => x.section === section.key)
                    width: col.width
                    spacing: 2

                    Text {
                        x: 10
                        topPadding: section.index === 0 ? 4 : 14
                        bottomPadding: 4
                        textFormat: Text.PlainText
                        text: ({ places: "Places", bookmarks: "Bookmarks", devices: "Devices" })[section.key]
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
                            required property int index
                            readonly property bool dragging: place.modelData.section === side.dragSection && place.index === side.dragFrom
                            readonly property int shift: side.dragFrom < 0 || place.dragging || place.modelData.section !== side.dragSection ? 0 : side.dragFrom < side.dragTo && place.index > side.dragFrom && place.index <= side.dragTo ? -36 : side.dragFrom > side.dragTo && place.index >= side.dragTo && place.index < side.dragFrom ? 36 : 0
                            readonly property var drive: place.modelData.drive
                            readonly property bool waiting: place.drive !== null && side.files.driveBusy === place.drive.id
                            readonly property bool away: place.drive !== null && (!place.drive.mounted || place.drive.locked)
                            readonly property bool ejects: place.drive !== null && !place.drive.locked && (place.drive.mounted || place.drive.drive !== "")
                            readonly property bool hot: area.containsMouse
                            width: section.width
                            height: 34
                            Component.onDestruction: {
                                if (place.dragging) {
                                    side.dragFrom = -1;
                                    side.dragTo = -1;
                                    side.dragY = 0;
                                }
                            }
                            z: place.dragging ? 1 : 0
                            transform: Translate {
                                y: place.dragging ? side.dragY : place.shift

                                Behavior on y {
                                    enabled: !place.dragging
                                    NumberAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }
                            }

                            Glass {
                                anchors.fill: parent
                                radius: Tokens.r(10)
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
                                property real pressY: 0
                                property bool moved: false
                                preventStealing: true
                                onCanceled: {
                                    side.dragFrom = -1;
                                    side.dragTo = -1;
                                    side.dragY = 0;
                                }
                                onPressed: mouse => {
                                    area.pressY = area.mapToItem(col, mouse.x, mouse.y).y;
                                    area.moved = false;
                                }
                                onPositionChanged: mouse => {
                                    if (!area.pressed || !(mouse.buttons & Qt.LeftButton))
                                        return;
                                    const dy = area.mapToItem(col, mouse.x, mouse.y).y - area.pressY;
                                    if (!area.moved && Math.abs(dy) < 6)
                                        return;
                                    area.moved = true;
                                    side.dragSection = place.modelData.section;
                                    side.dragFrom = place.index;
                                    const marks = place.modelData.section === "bookmarks";
                                    const lo = !marks || place.modelData.own ? 0 : side.ownCount;
                                    const hi = !marks ? section.rows.length - 1 : place.modelData.own ? side.ownCount - 1 : side.markCount - 1;
                                    side.dragY = Math.max((lo - place.index) * 36, Math.min((hi - place.index) * 36, dy));
                                    side.dragTo = place.index + Math.round(side.dragY / 36);
                                }
                                onReleased: {
                                    const from = side.dragFrom;
                                    const to = side.dragTo;
                                    side.dragFrom = -1;
                                    side.dragTo = -1;
                                    side.dragY = 0;
                                    if (from < 0 || to === from)
                                        return;
                                    if (place.modelData.section !== "bookmarks")
                                        side.files.moveRow(place.modelData.section, from, to);
                                    else if (place.modelData.own)
                                        side.files.moveBookmark(from, to);
                                    else
                                        side.files.moveGtkBookmark(section.rows[from].path, section.rows[to].path);
                                }
                                onClicked: mouse => {
                                    if (area.moved)
                                        return;
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
