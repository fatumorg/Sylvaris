import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    required property var lock
    property real reveal: 0

    Component.onCompleted: {
        revealAnim.restart();
        card.focusInput();
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: Math.round(700 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    Connections {
        target: root.lock
        function onFailed() {
            card.fail();
        }
        function onLockedChanged() {
            if (root.lock.locked) {
                card.clear();
                revealAnim.restart();
                card.focusInput();
            }
        }
    }

    Backdrop {
        anchors.fill: parent
        reveal: root.reveal
        dim: 0.45
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.14 + (1 - root.reveal) * -30)
        opacity: root.reveal
        spacing: 4

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(root.lock.now), root.lock.cfg.seconds ? "HH:mm:ss" : "HH:mm")
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Math.min(160, root.height * 0.14)
            font.weight: Font.Light
            font.features: {
                "tnum": 1
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(root.lock.now), "dddd, d MMMM")
            color: Theme.textSoft
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.titleSize + 4
        }
    }

    AuthCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.52 + (1 - root.reveal) * 40)
        width: 360
        opacity: root.reveal
        avatar: root.lock.avatar
        name: root.lock.user
        prompt: root.lock.awaiting ? root.lock.message : "Password"
        message: root.lock.awaiting ? "" : root.lock.message
        error: root.lock.error
        busy: root.lock.busy
        typed: root.lock.typed
        onEdited: text => root.lock.typed = text
        onSubmitted: text => root.lock.submit(text)
    }

    Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        opacity: 0.8 * root.reveal
        text: "Type your password and press Enter"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }
}
