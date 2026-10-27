import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../../lib/icons.mjs" as Icons

Scope {
    id: root

    property real phase: 0
    readonly property bool live: root.phase > 0
    property var shownAlarm: null
    readonly property bool ringing: Diver.alarm !== null
    readonly property bool wanted: panel.wanted
    readonly property var screenInfo: panel.screenInfo
    readonly property alias panel: panel

    signal opened

    function open(): void {
        panel.open();
    }

    function close(): void {
        panel.close();
    }

    function toggle(): void {
        panel.toggle();
    }

    function toggleOn(screen: var): void {
        panel.toggleOn(screen);
    }

    DiverPanel {
        id: panel
        onOpened: root.opened()
    }

    Component.onCompleted: Diver.planner = true
    Component.onDestruction: Diver.planner = false

    Connections {
        target: Diver
        function onAlarmChanged() {
            if (Diver.alarm !== null)
                root.shownAlarm = Diver.alarm;
        }
        function onOpenRequested(mode, id, day) {
            panel.open();
            if (mode === "edit")
                panel.edit(id, "");
            else if (mode === "new")
                panel.create(id, "", day);
            else
                panel.showDay(day);
        }
    }

    onRingingChanged: {
        if (root.ringing) {
            root.shownAlarm = Diver.alarm;
            outAnim.stop();
            inAnim.restart();
        } else {
            inAnim.stop();
            outAnim.restart();
        }
    }

    NumberAnimation {
        id: inAnim
        target: root
        property: "phase"
        to: 1
        duration: Math.round(700 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    NumberAnimation {
        id: outAnim
        target: root
        property: "phase"
        to: 0
        duration: Tokens.exitDuration + 100
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
    }

    onLiveChanged: {
        if (!root.live)
            keep.restart();
    }

    Timer {
        id: keep
        interval: 20000
    }

    LazyLoader {
        active: root.live || keep.running

        PanelWindow {
            id: win
            visible: root.phase > 0
            screen: Compositor.screenFor(Compositor.focusedName())
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Qt.alpha("#000000", 0.55 * root.phase)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "syldiver"
            WlrLayershell.keyboardFocus: root.ringing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    card.forceActiveFocus();
            }
            Component.onCompleted: {
                if (visible)
                    card.forceActiveFocus();
            }

            Item {
                id: card
                readonly property var a: root.shownAlarm
                anchors.centerIn: parent
                width: 520
                height: 420
                focus: true
                opacity: root.phase
                scale: 0.9 + 0.1 * root.phase
                Keys.onEscapePressed: Diver.dismiss()
                Keys.onReturnPressed: Diver.done(card.a.id)
                Keys.onSpacePressed: Diver.snooze(card.a.id, 10)

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20
                    width: 120
                    height: 120
                    radius: 60
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.danger

                    SequentialAnimation on scale {
                        running: root.ringing
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.92
                            to: 1.12
                            duration: Tokens.loopMs(700)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.enterCurve
                        }
                        NumberAnimation {
                            to: 0.92
                            duration: Tokens.loopMs(700)
                            easing.type: Easing.InOutSine
                        }
                    }

                    SequentialAnimation on opacity {
                        running: root.ringing
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1
                            to: 0.35
                            duration: Tokens.loopMs(700)
                        }
                        NumberAnimation {
                            to: 1
                            duration: Tokens.loopMs(700)
                        }
                    }
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20 + 60 - height / 2
                    text: Icons.GLYPHS.alarm
                    size: 54
                    color: Theme.danger
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 160
                    text: card.a === null ? "" : Qt.formatTime(new Date(card.a.start), "HH:mm")
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: 64
                    font.weight: Font.Light
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 244
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: card.a === null ? "" : card.a.title
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 290
                    text: card.a === null ? "" : "Diver" + (card.a.path !== "" ? " · " + card.a.path : "")
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: 10

                    Repeater {
                        model: [
                            {
                                label: "5 min",
                                act: 5
                            },
                            {
                                label: "10 min",
                                act: 10
                            },
                            {
                                label: "30 min",
                                act: 30
                            },
                            {
                                label: "Done",
                                act: 0
                            },
                            {
                                label: "Dismiss",
                                act: -1
                            }
                        ]

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: label.implicitWidth + 34
                            height: 44
                            opacity: Math.max(0, Math.min(1, root.phase * 3 - 1 - index * 0.2))
                            scale: area.pressed ? 0.92 : area.containsMouse ? 1.05 : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Tokens.stateDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Tokens.springCurve
                                }
                            }

                            Glass {
                                anchors.fill: parent
                                radius: height / 2
                                raised: true
                                lit: modelData.act === 0
                                hot: area.containsMouse
                            }

                            Text {
                                textFormat: Text.PlainText
                                id: label
                                anchors.centerIn: parent
                                text: modelData.act > 0 ? "Snooze " + modelData.label : modelData.label
                                color: modelData.act === 0 ? Theme.onAccent : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.bodySize
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (card.a === null)
                                        return;
                                    if (modelData.act > 0)
                                        Diver.snooze(card.a.id, modelData.act);
                                    else if (modelData.act === 0)
                                        Diver.done(card.a.id);
                                    else
                                        Diver.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
