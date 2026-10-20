import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/displays.mjs" as D
import "../lib/virtual.mjs" as V
import "../lib/icons.mjs" as Icons

Item {
    id: root

    signal closeRequested

    property var draft: JSON.parse(JSON.stringify(Displays.current))
    property string selected: root.firstEnabled()
    readonly property var names: Object.keys(root.draft).sort()
    readonly property var enabledNames: root.names.filter(n => root.draft[n].enabled)
    readonly property var fit: D.fitScale(root.draft, canvas.width, canvas.height, 24)
    readonly property var selectedOutput: root.outputFor(root.selected)
    readonly property var selectedDraft: root.draft[root.selected] === undefined ? null : root.draft[root.selected]
    readonly property var modes: root.selectedOutput === null ? [] : D.uniqueModes(root.selectedOutput.modes).slice(0, 6)
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property bool virtualSelected: root.selected === VirtualDisplay.name && VirtualDisplay.active
    property bool reveal: false

    Connections {
        target: Displays

        function onKeyChanged(): void {
            root.draft = JSON.parse(JSON.stringify(Displays.current));
            if (VirtualDisplay.active && root.draft[VirtualDisplay.name] !== undefined)
                root.selected = VirtualDisplay.name;
            else if (root.draft[root.selected] === undefined)
                root.selected = root.firstEnabled();
        }
    }

    function firstEnabled(): string {
        const keys = Object.keys(root.draft).sort();
        for (const k of keys) {
            if (root.draft[k].enabled)
                return k;
        }
        return keys.length > 0 ? keys[0] : "";
    }

    function outputFor(name: string): var {
        for (const o of Displays.outputs) {
            if (o.name === name)
                return o;
        }
        return null;
    }

    function patch(name: string, values: var): void {
        const next = JSON.parse(JSON.stringify(root.draft));
        next[name] = Object.assign({}, next[name], values);
        root.draft = next;
    }

    function setEnabled(name: string, on: bool): void {
        if (!on) {
            root.patch(name, {
                enabled: false
            });
            return;
        }
        const o = root.outputFor(name);
        const m = o === null ? null : (o.current !== null ? o.current : D.uniqueModes(o.modes)[0]);
        if (m === null || m === undefined)
            return;
        root.patch(name, {
            enabled: true,
            x: o.x,
            y: o.y,
            scale: o.scale,
            width: m.width,
            height: m.height,
            refresh: m.refresh
        });
    }

    function moveTo(name: string, px: real, py: real): void {
        const lx = Math.round(((px - 24) / root.fit.factor + root.fit.minX) / 10) * 10;
        const ly = Math.round(((py - 24) / root.fit.factor + root.fit.minY) / 10) * 10;
        root.patch(name, {
            x: Math.max(0, lx),
            y: Math.max(0, ly)
        });
    }

    ViewHeader {
        title: "Displays"
        onBack: root.closeRequested()
    }

    Rectangle {
        id: canvas
        x: 28
        y: 76
        width: parent.width - 56
        height: 230
        radius: Tokens.radiusCard
        color: "transparent"

        Glass {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            inner: true
            offBorder: Theme.cardLine
        }


        Repeater {
            model: root.enabledNames
            delegate: Rectangle {
                id: screenRect
                required property string modelData
                readonly property var o: root.draft[modelData]
                readonly property real baseX: 24 + (o.x - root.fit.minX) * root.fit.factor
                readonly property real baseY: 24 + (o.y - root.fit.minY) * root.fit.factor
                property real dx: 0
                property real dy: 0
                x: baseX + dx
                y: baseY + dy
                width: o.width / o.scale * root.fit.factor
                height: o.height / o.scale * root.fit.factor
                radius: 8
                color: modelData === root.selected ? Theme.fill : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                Glass {
                    anchors.fill: parent
                    z: -1
                    radius: parent.radius
                    inner: true
                    offColor: Theme.tintStrong
                }

                border.width: modelData === root.selected ? 2 : 1
                border.color: modelData === root.selected ? Theme.accent : Theme.lineStrong

                Behavior on border.color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: screenRect.modelData
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                TapHandler {
                    onTapped: root.selected = screenRect.modelData
                }

                DragHandler {
                    target: null
                    cursorShape: Qt.ClosedHandCursor
                    onTranslationChanged: {
                        screenRect.dx = translation.x;
                        screenRect.dy = translation.y;
                    }
                    onActiveChanged: {
                        if (active) {
                            root.selected = screenRect.modelData;
                            return;
                        }
                        const px = screenRect.baseX + screenRect.dx;
                        const py = screenRect.baseY + screenRect.dy;
                        screenRect.dx = 0;
                        screenRect.dy = 0;
                        root.moveTo(screenRect.modelData, px, py);
                    }
                }
            }
        }
    }

    Column {
        x: 28
        y: canvas.y + canvas.height + 14
        width: parent.width - 56
        spacing: 10

        Row {
            width: parent.width
            spacing: 10

            Repeater {
                model: root.names
                delegate: Rectangle {
                    required property string modelData
                    width: chipText.implicitWidth + 28
                    height: 34
                    radius: 17
                    color: modelData === root.selected ? Qt.alpha(Theme.accent, Resin.litAlpha) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.stateDuration
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        z: -1
                        radius: parent.radius
                        inner: true
                        offColor: Theme.tintMid
                    }


                    Text {
                        textFormat: Text.PlainText
                        id: chipText
                        anchors.centerIn: parent
                        text: modelData + (root.draft[modelData].enabled ? "" : " · off")
                        color: modelData === root.selected ? Theme.onAccent : Theme.text

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.stateDuration
                            }
                        }
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected = modelData
                    }
                }
            }

            Chip {
                visible: VirtualDisplay.available && !VirtualDisplay.active
                anchors.verticalCenter: parent.verticalCenter
                glyph: Icons.GLYPHS.plus
                text: VirtualDisplay.busy ? "Starting…" : "Virtual display"
                enabled: !VirtualDisplay.busy
                opacity: enabled ? 1 : 0.6
                onClicked: VirtualDisplay.start()
            }
        }

        Segmented {
            width: parent.width
            visible: root.selectedDraft !== null
            options: [
                {
                    key: "on",
                    label: "On"
                },
                {
                    key: "off",
                    label: "Off"
                }
            ]
            current: root.selectedDraft !== null && root.selectedDraft.enabled ? "on" : "off"
            onPicked: key => {
                if (root.virtualSelected && key === "off")
                    VirtualDisplay.stop();
                else
                    root.setEnabled(root.selected, key === "on");
            }
        }

        Flow {
            width: parent.width
            spacing: 8
            visible: root.virtualSelected

            Repeater {
                model: V.PRESETS
                delegate: Chip {
                    required property var modelData
                    text: modelData.label
                    lit: VirtualDisplay.width === modelData.width && VirtualDisplay.height === modelData.height
                    onClicked: VirtualDisplay.setSize(modelData.width, modelData.height)
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.virtualSelected
            wrapMode: Text.WordWrap
            text: "VNC " + (VirtualDisplay.addresses.length > 0 ? VirtualDisplay.addresses.map(a => a + ":" + VirtualDisplay.vnc.port).join("  ·  ") : "port " + VirtualDisplay.vnc.port) + (VirtualDisplay.vnc.username !== "" ? "  ·  user " + VirtualDisplay.vnc.username : "") + (VirtualDisplay.vnc.password !== "" ? "  ·  password " + (root.reveal ? VirtualDisplay.vnc.password : "••••••  (click to show)") : "")
            color: Theme.textSoft
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reveal = !root.reveal
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: VirtualDisplay.error !== ""
            wrapMode: Text.WordWrap
            text: VirtualDisplay.error
            color: Theme.danger
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Flow {
            width: parent.width
            spacing: 8
            visible: root.selectedDraft !== null && root.selectedDraft.enabled && !root.virtualSelected

            Repeater {
                model: root.modes
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: root.selectedDraft !== null && root.selectedDraft.width === modelData.width && root.selectedDraft.height === modelData.height && Math.abs(root.selectedDraft.refresh - modelData.refresh) < 0.01
                    width: modeText.implicitWidth + 24
                    height: 32
                    radius: 10
                    color: on ? Theme.fill : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.stateDuration
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        z: -1
                        radius: parent.radius
                        inner: true
                        offColor: Theme.tintSoft
                    }

                    border.width: on ? 1 : 0
                    border.color: Theme.accent

                    Text {
                        textFormat: Text.PlainText
                        id: modeText
                        anchors.centerIn: parent
                        text: D.modeLabel(modelData, root.modes)
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.patch(root.selected, {
                            width: modelData.width,
                            height: modelData.height,
                            refresh: modelData.refresh
                        })
                    }
                }
            }
        }

        Row {
            spacing: 8
            visible: root.selectedDraft !== null && root.selectedDraft.enabled

            Repeater {
                model: root.scales
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: root.selectedDraft !== null && Math.abs(root.selectedDraft.scale - modelData) < 0.001
                    width: 64
                    height: 32
                    radius: 10
                    color: on ? Theme.fill : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.stateDuration
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        z: -1
                        radius: parent.radius
                        inner: true
                        offColor: Theme.tintSoft
                    }

                    border.width: on ? 1 : 0
                    border.color: Theme.accent

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: modelData + "×"
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.patch(root.selected, {
                            scale: modelData
                        })
                    }
                }
            }
        }
    }

    Row {
        x: (parent.width - width) / 2
        y: parent.height - height - 24
        spacing: 10
        visible: Displays.countdown === 0

        RowButton {
            icon: Icons.GLYPHS.check
            label: "Apply"
            onClicked: Displays.apply(root.draft)
        }

        RowButton {
            icon: Icons.GLYPHS.displays
            label: "Save layout"
            onClicked: Displays.save()
        }

        RowButton {
            icon: Icons.GLYPHS.scan
            label: "Reset"
            onClicked: root.draft = JSON.parse(JSON.stringify(Displays.current))
        }
    }

    Rectangle {
        visible: Displays.countdown > 0
        x: 28
        y: parent.height - height - 20
        width: parent.width - 56
        height: 64
        radius: Tokens.radiusCard
        color: "transparent"

        Glass {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            raised: true
            offColor: Theme.node
        }

        border.width: 1
        border.color: Theme.accent

        Text {
            textFormat: Text.PlainText
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "Keep this layout? Reverting in " + Displays.countdown + " s"
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            RowButton {
                label: "Keep"
                icon: Icons.GLYPHS.check
                onClicked: Displays.keep()
            }

            RowButton {
                label: "Revert"
                icon: Icons.GLYPHS.close
                onClicked: Displays.revert()
            }
        }
    }
}
