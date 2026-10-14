import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FocusScope {
    id: bar

    required property var files

    implicitHeight: 34

    Connections {
        target: bar.files

        function onFocusLocation(): void {
            input.text = bar.files.path;
            input.selectAll();
            input.forceActiveFocus();
        }
    }

    Glass {
        anchors.fill: parent
        radius: height / 2
        inner: true
        hot: back.containsMouse && !bar.files.locating
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

    MouseArea {
        id: back
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: bar.files.locating ? Qt.IBeamCursor : Qt.PointingHandCursor
        onClicked: bar.files.act("location")
    }

    ListView {
        id: crumbs
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        visible: !bar.files.locating
        orientation: ListView.Horizontal
        interactive: false
        clip: true
        model: bar.files.path === "" ? [] : F.crumbs(bar.files.path, bar.files.home)
        onCountChanged: Qt.callLater(crumbs.positionViewAtEnd)
        onWidthChanged: Qt.callLater(crumbs.positionViewAtEnd)

        delegate: Item {
            id: crumb
            required property var modelData
            required property int index
            readonly property bool last: crumb.index === crumbs.count - 1
            width: sep.width + chip.width
            height: crumbs.height

            Glyph {
                id: sep
                width: crumb.index === 0 ? 0 : 16
                visible: crumb.index > 0
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.chevronRight
                size: 13
                color: Theme.textDim
            }

            Item {
                id: chip
                x: sep.width
                width: label.implicitWidth + (home.visible ? home.width + 6 : 0) + 20
                height: parent.height - 6
                anchors.verticalCenter: parent.verticalCenter

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    inner: true
                    flowing: false
                    hot: area.containsMouse || drop.containsDrag
                    lit: drop.containsDrag
                    opacity: area.containsMouse || drop.containsDrag ? 1 : 0
                    offColor: Theme.tintMid
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Glyph {
                        id: home
                        visible: crumb.modelData.home
                        anchors.verticalCenter: parent.verticalCenter
                        text: F.GLYPH.home
                        size: 15
                        color: Theme.accent
                    }

                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: crumb.modelData.label
                        color: crumb.last ? Theme.text : Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                        font.weight: crumb.last ? Font.DemiBold : Font.Normal
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton)
                            bar.files.newTab(crumb.modelData.path);
                        else
                            bar.files.go(crumb.modelData.path);
                    }
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    enabled: !crumb.last
                    onDropped: d => {
                        const action = d.proposedAction === Qt.CopyAction || !(d.supportedActions & Qt.MoveAction) ? Qt.CopyAction : Qt.MoveAction;
                        bar.files.dropped(crumb.modelData.path, d.urls, action);
                        d.accept(action);
                    }
                }
            }
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: bar.files.locating
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
        selectByMouse: true
        Keys.onReturnPressed: go()
        Keys.onEnterPressed: go()
        Keys.onEscapePressed: {
            bar.files.locating = false;
            bar.files.focusView();
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                bar.files.locating = false;
        }

        function go(): void {
            try {
                bar.files.goTo(input.text);
            } catch (e) {
                bar.files.say(String(e.message || e), false);
            }
            bar.files.locating = false;
            bar.files.focusView();
        }
    }
}
