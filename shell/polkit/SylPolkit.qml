import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Scope {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    property var preview: null
    readonly property var agent: agentLoader.item
    readonly property var flow: root.preview !== null ? root.preview : root.agent !== null ? root.agent.flow : null
    readonly property bool shown: root.flow !== null && root.flow !== undefined && !root.flow.isCompleted
    readonly property bool wanted: root.shown
    property var screenInfo: null
    property real phase: 0
    property bool busy: false
    readonly property bool live: root.shown || root.phase > 0

    signal opened
    signal failed

    function submit(text: string): void {
        if (!root.shown || root.busy)
            return;
        root.busy = true;
        root.flow.submit(text);
    }

    function cancel(): void {
        if (root.shown)
            root.flow.cancelAuthenticationRequest();
    }

    function close(): void {
    }

    function open(): void {
    }

    function toggle(): void {
    }

    function toggleOn(screen: var): void {
    }

    function showPreview(): void {
        root.preview = previewComponent.createObject(root);
    }

    function state(): var {
        return {
            registered: root.agent !== null && root.agent.isRegistered,
            active: root.shown,
            message: root.shown ? root.flow.message : "",
            prompt: root.shown ? root.flow.inputPrompt : "",
            error: root.shown ? root.flow.supplementaryMessage : ""
        };
    }

    onShownChanged: {
        if (root.shown) {
            root.busy = false;
            root.screenInfo = Compositor.screenFor(Compositor.focusedName());
            outAnim.stop();
            inAnim.restart();
            root.opened();
        } else {
            inAnim.stop();
            outAnim.restart();
            const done = root.preview;
            if (done !== null)
                Qt.callLater(() => {
                    if (root.preview === done)
                        root.preview = null;
                    done.destroy();
                });
        }
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.busy = false;
            root.failed();
        }
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired)
                root.busy = false;
        }
    }

    LazyLoader {
        id: agentLoader
        active: !Demo.enabled

        PolkitAgent {}
    }

    Component {
        id: previewComponent

        QtObject {
            id: fake
            property string message: "Authentication is needed to change the system time zone"
            property string iconName: ""
            property string actionId: "org.freedesktop.timedate1.set-timezone"
            property var selectedIdentity: null
            property bool isResponseRequired: true
            property string inputPrompt: "Password:"
            property bool responseVisible: false
            property string supplementaryMessage: ""
            property bool supplementaryIsError: false
            property bool isCompleted: false
            signal authenticationFailed

            function submit(value: string): void {
                if (value === "right") {
                    fake.isCompleted = true;
                } else {
                    fake.supplementaryMessage = "That password did not work, try again";
                    fake.supplementaryIsError = true;
                    fake.authenticationFailed();
                }
            }

            function cancelAuthenticationRequest(): void {
                fake.isCompleted = true;
            }
        }
    }

    NumberAnimation {
        id: inAnim
        target: root
        property: "phase"
        to: 1
        duration: Math.round(320 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    NumberAnimation {
        id: outAnim
        target: root
        property: "phase"
        to: 0
        duration: Math.round(200 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
    }

    LazyLoader {
        active: root.live

        PanelWindow {
            visible: root.live
            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Qt.alpha("#000000", 0.45 * root.phase)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylpolkit"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Component.onCompleted: card.focusInput()

            Item {
                id: panel
                anchors.centerIn: parent
                width: 460
                height: body.implicitHeight + 56
                opacity: root.phase
                scale: 0.95 + 0.05 * root.phase
                focus: true
                Keys.onEscapePressed: root.cancel()

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Column {
                    id: body
                    x: 28
                    y: 28
                    width: parent.width - 56
                    spacing: 16

                    Row {
                        spacing: 12

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.GLYPHS.lock
                            size: 22
                            color: Theme.accent
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Authentication required"
                            color: Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.titleSize + 2
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.shown ? root.flow.message : ""
                        color: Theme.textSoft
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                        lineHeight: 1.2
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        visible: text !== ""
                        elide: Text.ElideMiddle
                        text: root.shown ? root.flow.actionId : ""
                        color: Theme.textDim
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.tinySize
                    }

                    AuthCard {
                        id: card
                        width: parent.width
                        name: root.shown && root.flow.selectedIdentity ? root.flow.selectedIdentity.displayName || root.user : root.user
                        avatar: ""
                        prompt: root.shown && root.flow.inputPrompt !== "" ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                        secret: !(root.shown && root.flow.responseVisible)
                        message: root.shown ? root.flow.supplementaryMessage : ""
                        error: root.shown && root.flow.supplementaryIsError
                        busy: root.busy
                        onSubmitted: text => root.submit(text)

                        Connections {
                            target: root
                            function onFailed() {
                                card.fail();
                            }
                        }
                    }

                    RowButton {
                        anchors.right: parent.right
                        label: "Cancel"
                        icon: Icons.GLYPHS.close
                        onClicked: root.cancel()
                    }
                }
            }
        }
    }
}
