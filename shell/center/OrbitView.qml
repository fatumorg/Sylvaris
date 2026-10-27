import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/orbit.mjs" as O
import "../lib/icons.mjs" as Icons

Item {
    id: root

    property string mode: "bluetooth"
    property string initialFocus: ""
    property string focusKey: ""
    property string pendingForget: ""
    property bool passwordOpen: false
    property bool listOpen: false
    property bool copied: false

    signal modeRequested(string mode)
    signal closeRequested

    readonly property bool isBt: root.mode === "bluetooth"
    readonly property var service: root.isBt ? BluetoothService : NetworkService
    readonly property var items: root.service.items
    readonly property var capped: O.orderAndCap(root.items)
    readonly property bool serviceOn: root.service.enabled && (root.isBt || NetworkService.hasWifi)
    readonly property var focused: {
        if (root.focusKey === "")
            return null;
        for (const i of root.items) {
            if (i.key === root.focusKey)
                return i;
        }
        return null;
    }
    readonly property bool errorShown: root.service.error !== "" && (root.focusKey === "" || root.service.errorKey === root.focusKey)
    readonly property string status: {
        if (root.errorShown)
            return root.service.error;
        const f = root.focused;
        if (f !== null) {
            if (O.busyLabel(f.phase) !== "")
                return O.busyLabel(f.phase);
            if (root.isBt)
                return f.connected ? "Connected" + (f.battery >= 0 ? " · " + f.battery + "%" : "") : (f.known ? "Paired" : "Not paired");
            return f.connected ? "Connected" : (f.known ? "Saved" : "Not connected");
        }
        if (!root.isBt && !NetworkService.hasWifi)
            return "No Wi-Fi adapter";
        return root.service.summary;
    }

    Component.onCompleted: root.focusKey = root.initialFocus
    onInitialFocusChanged: root.focusKey = root.initialFocus
    onModeChanged: root.unfocus()
    onFocusedChanged: {
        if (root.focusKey !== "" && root.focused === null)
            root.unfocus();
    }

    function unfocus(): void {
        root.focusKey = "";
        root.pendingForget = "";
        root.passwordOpen = false;
        root.copied = false;
    }

    function back(): bool {
        if (root.passwordOpen) {
            root.passwordOpen = false;
            return true;
        }
        if (root.listOpen) {
            root.listOpen = false;
            return true;
        }
        if (root.focusKey !== "") {
            root.unfocus();
            return true;
        }
        return false;
    }

    function subFor(i: var): string {
        if (O.busyLabel(i.phase) !== "")
            return O.busyLabel(i.phase);
        if (root.isBt)
            return i.connected ? (i.battery >= 0 ? i.battery + "%" : "Connected") : (i.known ? "Paired" : "");
        return i.connected ? "Connected" : (i.known ? "Saved" : (i.open ? "Open" : ""));
    }

    function controllerNodes(): var {
        if (!root.serviceOn)
            return [
                {
                    key: "__on",
                    icon: Icons.GLYPHS.power,
                    label: "Turn on",
                    bold: true,
                    linked: true
                }
            ];
        const out = root.capped.visible.map(i => ({
                    key: i.key,
                    icon: i.icon,
                    label: i.name,
                    sub: root.subFor(i),
                    linked: i.connected,
                    dim: !i.connected && !i.known
                }));
        if (root.capped.overflow > 0)
            out.push({
                key: "__more",
                icon: Icons.GLYPHS.more,
                label: "+" + root.capped.overflow + " more"
            });
        out.push({
            key: "__scan",
            icon: Icons.GLYPHS.scan,
            label: root.service.scanning ? "Scanning…" : "Scan"
        });
        return out;
    }

    function focusNodes(): var {
        const i = root.focused;
        const out = [];
        out.push({
            key: "connect",
            icon: i.connected ? (root.isBt ? Icons.GLYPHS.disconnect : Icons.GLYPHS.wifiOff) : Icons.GLYPHS.link,
            label: O.actionLabel(i, root.isBt),
            bold: true,
            linked: true
        });
        if (root.isBt) {
            if (i.battery >= 0)
                out.push({
                    key: "battery",
                    icon: Icons.batteryIcon(i.battery),
                    label: "Battery",
                    sub: i.battery + "%",
                    linked: true
                });
            const prof = i.audio && i.connected ? BluetoothService.profile(i.key) : null;
            if (prof !== null)
                out.push({
                    key: "profile",
                    icon: Icons.GLYPHS.speaker,
                    label: prof.label,
                    sub: "Audio profile",
                    linked: true
                });
            if (i.known)
                out.push({
                    key: "trusted",
                    icon: Icons.GLYPHS.trusted,
                    label: "Trusted",
                    sub: i.trusted ? "On" : "Off",
                    linked: true
                });
        } else {
            out.push({
                key: "signal",
                icon: i.icon,
                label: "Signal",
                sub: i.signal >= 0 ? Math.round(i.signal * 100) + "%" : "Unknown",
                linked: true
            });
            out.push({
                key: "security",
                icon: Icons.GLYPHS.lock,
                label: i.open ? "Open network" : i.security,
                sub: "Security",
                linked: true
            });
            if (!i.open)
                out.push({
                    key: "password",
                    icon: Icons.GLYPHS.eye,
                    label: "Password",
                    sub: i.known ? "Change" : "Enter",
                    linked: true
                });
        }
        if (i.known)
            out.push({
                key: "forget",
                icon: Icons.GLYPHS.forget,
                label: root.pendingForget === i.key ? "Click again to forget" : "Forget",
                danger: true,
                linked: true
            });
        if (root.isBt)
            out.push({
                key: "address",
                icon: Icons.GLYPHS.copy,
                label: i.key,
                sub: root.copied ? "Copied" : "tap to copy",
                linked: true
            });
        return out;
    }

    function onNode(key: string): void {
        if (root.focusKey === "") {
            if (key === "__on")
                root.service.setEnabled(true);
            else if (key === "__scan")
                root.service.scan(!root.service.scanning);
            else if (key === "__more")
                root.listOpen = true;
            else
                root.focusKey = key;
            return;
        }
        const i = root.focused;
        if (i === null)
            return;
        if (key === "connect") {
            if (i.phase !== "")
                return;
            if (i.connected)
                root.service.disconnect(i.key);
            else if (!root.isBt && NetworkService.needsPassword(i.key))
                root.passwordOpen = true;
            else
                root.service.connect(i.key);
        } else if (key === "profile") {
            BluetoothService.switchProfile(i.key);
        } else if (key === "trusted") {
            BluetoothService.setTrusted(i.key, !i.trusted);
        } else if (key === "password") {
            root.passwordOpen = true;
        } else if (key === "forget") {
            if (root.pendingForget === i.key) {
                root.service.forget(i.key);
                root.unfocus();
            } else {
                root.pendingForget = i.key;
                forgetTimer.restart();
            }
        } else if (key === "address") {
            Stack.execDetached(["wl-copy", i.key]);
            root.copied = true;
            copiedTimer.restart();
        }
    }

    function submitPassword(): void {
        if (psk.text.length === 0 || root.focused === null)
            return;
        NetworkService.connectWithPsk(root.focused.key, psk.text);
        root.passwordOpen = false;
    }

    onPasswordOpenChanged: {
        if (root.passwordOpen) {
            psk.text = "";
            psk.focusInput();
        }
    }

    Timer {
        id: forgetTimer
        interval: 4000
        onTriggered: root.pendingForget = ""
    }

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: root.copied = false
    }

    Orbit {
        anchors.fill: parent
        coreIcon: root.focused !== null ? root.focused.icon : (root.isBt ? Icons.GLYPHS.bluetooth : Icons.GLYPHS.wifi)
        coreName: root.focused !== null ? root.focused.name : (root.isBt ? "Bluetooth" : "Wi-Fi")
        coreStatus: root.status
        statusError: root.errorShown
        scanning: root.focusKey === "" && root.service.scanning
        nodes: root.focusKey === "" ? root.controllerNodes() : root.focusNodes()
        opacity: root.passwordOpen || root.listOpen ? 0.25 : 1
        enabled: !root.passwordOpen && !root.listOpen
        onNodeClicked: key => root.onNode(key)
    }

    Item {
        x: 24
        y: 22
        width: backRow.width
        height: backRow.height

        Row {
            id: backRow
            spacing: 10

            Rectangle {
                visible: root.focusKey !== ""
                width: Tokens.moonSize
                height: Tokens.moonSize
                radius: width / 2
                color: Theme.moon

                Glyph {
                    anchors.centerIn: parent
                    text: root.isBt ? Icons.GLYPHS.bluetooth : Icons.GLYPHS.wifi
                    size: 18
                    color: Theme.text
                }
            }

            Glyph {
                visible: root.focusKey === ""
                text: Icons.GLYPHS.back
                size: 26
                color: Theme.accent
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.focusKey !== ""
                text: root.isBt ? "Bluetooth" : "Wi-Fi"
                color: Theme.textSoft
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.nodeSize
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.focusKey !== "")
                    root.unfocus();
                else
                    root.closeRequested();
            }
        }
    }

    Segmented {
        x: Tokens.segmentedSide
        y: parent.height - height - Tokens.segmentedBottom
        width: parent.width - Tokens.segmentedSide * 2
        options: [
            {
                key: "wifi",
                icon: Icons.GLYPHS.wifi,
                label: "Wi-Fi"
            },
            {
                key: "bluetooth",
                icon: Icons.GLYPHS.bluetooth,
                label: "Bluetooth"
            }
        ]
        current: root.mode
        onPicked: key => root.modeRequested(key)
    }

    Rectangle {
        visible: root.serviceOn
        x: parent.width - width - 22
        y: parent.height - height - 24
        width: Tokens.powerSize
        height: Tokens.powerSize
        radius: width / 2
        color: Qt.alpha(Theme.accent, Resin.litAlpha)

        Glyph {
            anchors.centerIn: parent
            text: Icons.GLYPHS.power
            size: 22
            color: Theme.onAccent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.service.setEnabled(false);
                root.closeRequested();
            }
        }
    }

    Rectangle {
        visible: root.passwordOpen
        anchors.centerIn: parent
        width: 400
        height: 200
        radius: Tokens.radiusCard
        color: "transparent"

        Glass {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            raised: true
            offColor: Theme.node
            offBorder: Theme.lineStrong
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: "Password for " + (root.focused !== null ? root.focused.name : "")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }

            TextBox {
                id: psk
                width: parent.width
                password: true
                placeholder: "Password"
                onAccepted: root.submitPassword()
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                RowButton {
                    label: "Cancel"
                    icon: Icons.GLYPHS.close
                    onClicked: root.passwordOpen = false
                }

                RowButton {
                    label: "Connect"
                    icon: Icons.GLYPHS.link
                    onClicked: root.submitPassword()
                }
            }
        }
    }

    Rectangle {
        visible: root.listOpen
        anchors.fill: parent
        anchors.margins: 24
        anchors.bottomMargin: 90
        radius: Tokens.radiusCard
        color: "transparent"

        Glass {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            raised: true
            offColor: Theme.node
            offBorder: Theme.lineStrong
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            spacing: 6
            model: O.orderAndCap(root.items, 1000).visible
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 48
                radius: 12
                color: rowHover.hovered ? Theme.tintMid : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                }

                Glyph {
                    id: rowIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.icon
                    size: 20
                    color: Theme.accent
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12
                    anchors.right: rowSub.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                }

                Text {
                    textFormat: Text.PlainText
                    id: rowSub
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.subFor(modelData)
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.listOpen = false;
                        root.focusKey = modelData.key;
                    }
                }
            }
        }
    }
}
