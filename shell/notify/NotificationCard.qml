import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/notify.mjs" as N
import "../lib/icons.mjs" as Icons

Item {
    id: root

    required property var entry
    property bool toast: false
    property int duration: 0
    readonly property var n: root.entry.n
    readonly property bool hovered: hover.hovered
    readonly property bool critical: root.n.urgency === NotificationUrgency.Critical
    readonly property string icon: N.iconSource(root.n.appIcon !== "" ? root.n.appIcon : root.n.image && !N.isPicture(root.n.image) ? root.n.image : root.desktopIcon(), name => Stack.iconPath(name, true))
    readonly property string picture: N.isPicture(root.n.image) ? N.iconSource(root.n.image, name => "") : ""
    readonly property var buttons: root.n.actions.filter(a => a.identifier !== "default" && a.text !== "")
    property real progress: 1
    property real leave: 0

    signal gone

    implicitHeight: Math.max(content.implicitHeight, Tokens.notifyIcon, thumb.visible ? Tokens.notifyThumb : 0) + Tokens.cardPadding * 2

    function desktopIcon(): string {
        if (!root.n.desktopEntry)
            return "";
        const e = Apps.entry(root.n.desktopEntry);
        return e ? e.icon : "";
    }

    function out(then: var): void {
        leaveAnim.then = then;
        leaveAnim.restart();
    }

    opacity: 1 - root.leave
    transform: Translate {
        x: root.leave * 60
    }

    NumberAnimation {
        id: leaveAnim
        property var then: null
        target: root
        property: "leave"
        to: 1
        duration: Tokens.stateDuration + 60
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
        onFinished: {
            if (then)
                then();
            root.gone();
        }
    }

    FrameAnimation {
        running: root.toast && root.duration > 0 && !root.hovered && root.progress > 0 && root.leave === 0
        onTriggered: {
            root.progress = Math.max(0, root.progress - frameTime * 1000 / root.duration);
            if (root.progress === 0)
                root.out(() => Notifications.hideToast(root.entry.id));
        }
    }

    HoverHandler {
        id: hover
    }

    Glass {
        anchors.fill: parent
        radius: root.toast ? Tokens.radiusPanel : Tokens.radiusCard
        inner: !root.toast
        raised: root.toast
        hot: root.hovered && !root.toast
        offColor: root.toast ? Theme.surface : Theme.tint
        offBorder: root.critical ? Theme.danger : root.toast ? Theme.line : Theme.cardLine
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifications.invoke(root.entry.id, "default")
    }

    Rectangle {
        visible: root.critical
        x: 0
        width: 3
        height: parent.height - 2 * Tokens.radiusCard
        anchors.verticalCenter: parent.verticalCenter
        radius: 1.5
        color: Theme.danger
    }

    Item {
        id: iconBox
        x: Tokens.cardPadding
        y: Tokens.cardPadding
        width: Tokens.notifyIcon
        height: Tokens.notifyIcon

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusRow - 2
            color: Qt.alpha(Theme.accent, 0.18)
            visible: iconImage.status !== Image.Ready

            Glyph {
                anchors.centerIn: parent
                text: Icons.GLYPHS.bell
                size: 18
                color: Theme.accent
            }
        }

        Image {
            id: iconImage
            anchors.fill: parent
            source: root.icon
            layer.enabled: Tokens.iconTint
            layer.effect: IconTint {}
            sourceSize.width: Tokens.notifyIcon * 2
            sourceSize.height: Tokens.notifyIcon * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: root.icon.indexOf("image://") !== 0
            smooth: true
            mipmap: true
            visible: status === Image.Ready
        }
    }

    Column {
        id: content
        anchors.left: iconBox.right
        anchors.leftMargin: 12
        anchors.right: thumb.visible ? thumb.left : parent.right
        anchors.rightMargin: thumb.visible ? 12 : Tokens.cardPadding
        y: Tokens.cardPadding - 2
        spacing: 3

        Item {
            width: parent.width
            height: appLine.implicitHeight

            Text {
                textFormat: Text.PlainText
                id: appLine
                width: parent.width - 60
                text: (root.n.appName || "Notification") + "  ·  " + N.ago(root.entry.time, Notifications.now)
                elide: Text.ElideRight
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }

            Glyph {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.close
                size: 16
                color: closeArea.containsMouse ? Theme.text : Theme.textDim
                opacity: root.hovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.out(() => root.toast ? Notifications.hideToast(root.entry.id) : Notifications.dismiss(root.entry.id))
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: text !== ""
            text: N.plainText(root.n.summary)
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: root.n.body !== ""
            text: N.cleanBody(root.n.body)
            textFormat: Text.StyledText
            linkColor: Theme.accent
            elide: Text.ElideRight
            maximumLineCount: root.toast ? 4 : 3
            wrapMode: Text.Wrap
            color: Theme.textSoft
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
            onLinkActivated: link => {
                if (/^(https?|mailto):/i.test(link))
                    Qt.openUrlExternally(link);
            }
        }

        Item {
            width: 1
            height: root.buttons.length > 0 ? 6 : 0
        }

        Row {
            width: parent.width
            visible: root.buttons.length > 0
            spacing: 8

            Repeater {
                model: root.buttons
                delegate: Item {
                    required property var modelData
                    width: Math.min(label.implicitWidth + 28, (content.width - 8 * (root.buttons.length - 1)) / root.buttons.length)
                    height: 34

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                        inner: true
                        hot: buttonArea.containsMouse
                        offBorder: Theme.cardLine
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: label
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 20)
                        text: modelData.text
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: buttonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.invoke(root.entry.id, modelData.identifier)
                    }
                }
            }
        }
    }

    Item {
        id: thumb
        visible: root.picture !== "" && thumbImage.status === Image.Ready
        anchors.right: parent.right
        anchors.rightMargin: Tokens.cardPadding
        y: Tokens.cardPadding
        width: Tokens.notifyThumb
        height: Tokens.notifyThumb

        RoundClip {
            anchors.fill: parent
            radius: Tokens.radiusRow - 2

            Image {
                id: thumbImage
                width: thumb.width
                height: thumb.height
                source: root.picture
                sourceSize.width: Tokens.notifyThumb * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
    }

    Rectangle {
        visible: root.toast && root.duration > 0
        x: Tokens.radiusPanel
        y: parent.height - 3
        width: (parent.width - Tokens.radiusPanel * 2) * root.progress
        height: 2
        radius: Tokens.r(1)
        color: Qt.alpha(Theme.accent, 0.7)
    }
}
