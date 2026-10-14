import QtQuick
import qs
import qs.services
import qs.components

FocusScope {
    id: ask

    required property var files
    readonly property var spec: ask.files.asking
    readonly property bool open: ask.spec !== null
    readonly property bool busy: ask.open && ask.spec.busy === true
    readonly property var choices: ask.open && ask.spec.choices ? ask.spec.choices : []
    property string choice: ""

    visible: card.opacity > 0
    onOpenChanged: {
        if (ask.open) {
            field.text = ask.spec.value || "";
            ask.choice = ask.spec.choice || "";
            showAnim.restart();
            Qt.callLater(field.focusInput);
        } else {
            field.text = "";
            card.opacity = 0;
            ask.files.focusView();
        }
    }

    function submit(): void {
        if (ask.open && !ask.busy)
            ask.files.answer(field.text, ask.choice);
    }

    Keys.onEscapePressed: ask.files.cancelAsk()
    Keys.onReturnPressed: ask.submit()
    Keys.onEnterPressed: ask.submit()

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.base, 0.45)
        opacity: card.opacity
    }

    MouseArea {
        anchors.fill: parent
        enabled: ask.open
        acceptedButtons: Qt.AllButtons
        onClicked: ask.files.cancelAsk()
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 440)
        height: body.height + 44
        opacity: 0
        scale: 0.96 + 0.04 * card.opacity

        NumberAnimation {
            id: showAnim
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusPanel
            raised: true
            offColor: Theme.surface
            offBorder: Theme.line
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: body
            x: 24
            y: 22
            width: parent.width - 48
            spacing: 14

            Row {
                width: parent.width
                spacing: 12

                Glyph {
                    id: mark
                    anchors.verticalCenter: parent.verticalCenter
                    text: ask.open ? ask.spec.glyph || "" : ""
                    size: 24
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - mark.width - 12
                    textFormat: Text.PlainText
                    text: ask.open ? ask.spec.title : ""
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.titleSize
                    font.weight: Font.DemiBold
                }
            }

            Text {
                visible: text !== ""
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: ask.open ? ask.spec.text || "" : ""
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            TextBox {
                id: field
                width: parent.width
                password: ask.open && ask.spec.password === true
                placeholder: ask.open ? ask.spec.placeholder || "" : ""
                enabled: !ask.busy
                opacity: ask.busy ? 0.6 : 1
            }

            Segmented {
                visible: ask.choices.length > 0
                width: parent.width
                options: ask.choices
                current: ask.choice
                onPicked: key => ask.choice = key
            }

            Text {
                visible: text !== ""
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: ask.open ? ask.spec.error || "" : ""
                color: Theme.danger
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                PillButton {
                    label: "Cancel"
                    onClicked: ask.files.cancelAsk()
                }

                PillButton {
                    label: ask.busy ? "Working…" : ask.open ? ask.spec.button : ""
                    primary: true
                    enabled: !ask.busy && field.text.trim() !== ""
                    onClicked: ask.submit()
                }
            }
        }
    }
}
