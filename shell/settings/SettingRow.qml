import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool last: false
    property string key: ""
    property bool advanced: false
    readonly property bool modified: root.key !== "" && Settings.isModified(root.key)
    default property alias control: slot.data

    width: parent ? parent.width : 0
    visible: !root.advanced || Settings.more || Settings.values.settings.detail === "full"

    Connections {
        target: Settings
        function onFocusKeyChanged(): void {
            if (root.key !== "" && Settings.focusKey === root.key)
                flash.restart();
        }
    }

    Rectangle {
        id: glow
        anchors.fill: parent
        anchors.leftMargin: -10
        anchors.rightMargin: -10
        radius: Tokens.radiusRow
        color: Qt.alpha(Theme.accent, 0.2)
        opacity: 0
    }

    SequentialAnimation {
        id: flash
        NumberAnimation {
            target: glow
            property: "opacity"
            to: 1
            duration: Tokens.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
        PauseAnimation {
            duration: Tokens.ms(900)
        }
        NumberAnimation {
            target: glow
            property: "opacity"
            to: 0
            duration: Tokens.ms(700)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.exitCurve
        }
    }
    implicitHeight: Math.max(Tokens.settingsRow, labels.implicitHeight + 24, slot.childrenRect.height + 20)

    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            id: titleText
            textFormat: Text.PlainText
            width: parent.width - (root.modified ? 90 : 0)
            text: root.title
            elide: Text.ElideRight
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize

            Row {
                id: reset
                x: titleText.contentWidth + 10
                anchors.verticalCenter: parent.verticalCenter
                visible: root.modified
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: width / 2
                    color: Theme.accent
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: resetArea.hovered
                    text: "Reset"
                    color: Theme.accentHi
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }

                HoverHandler {
                    id: resetArea
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Settings.reset(root.key)
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            wrapMode: Text.Wrap
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Divider {
        visible: !root.last
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
