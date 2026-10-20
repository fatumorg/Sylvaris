import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import "../lib/bar.mjs" as B
import "../lib/icons.mjs" as Icons

Scope {
    id: root

    property var screens: Quickshell.screens
    readonly property var cfg: Settings.at(root.screens.length === 1 ? root.screens[0].name : "").deck
    readonly property int size: root.cfg.size
    readonly property real reach: root.size * 2.6
    readonly property var windows: Compositor.windows
    readonly property var items: B.deckItems(root.cfg.pinned, root.windows, appId => root.entryId(appId))
    property bool padOpen: false

    signal request(string part, string arg, var screen)

    function entry(id: string): var {
        if (Demo.enabled)
            return Apps.byId(id);
        return Apps.entry(id);
    }

    function entryId(appId: string): string {
        if (Demo.enabled)
            return appId;
        const e = Apps.entry(appId);
        return e ? e.id : appId;
    }

    function nameOf(id: string): string {
        const e = root.entry(id);
        return e ? e.name : id;
    }

    function pin(id: string): void {
        Settings.set("deck.pinned", B.togglePin(root.cfg.pinned, id));
    }

    function click(item: var): void {
        const next = B.nextWindow(item.windows, root.windows);
        if (next >= 0)
            Compositor.activate(root.windows[next]);
        else
            Apps.launch(root.entry(item.id));
    }

    function slots(): var {
        const out = [];
        if (root.cfg.power === "start")
            out.push({
                kind: "power"
            });
        if (root.cfg.pad === "start")
            out.push({
                kind: "pad"
            });
        let pinnedDone = false;
        for (const it of root.items) {
            if (!it.pinned && !pinnedDone) {
                pinnedDone = true;
                if (out.length > 0)
                    out.push({
                        kind: "gap"
                    });
            }
            out.push({
                kind: "app",
                item: it
            });
        }
        if (root.cfg.pad === "end") {
            if (out.length > 0)
                out.push({
                    kind: "gap"
                });
            out.push({
                kind: "pad"
            });
        }
        if (root.cfg.power === "end") {
            if (out.length > 0 && root.cfg.pad !== "end")
                out.push({
                    kind: "gap"
                });
            out.push({
                kind: "power"
            });
        }
        return out;
    }

    Variants {
        model: root.cfg.enabled ? root.screens : []

        delegate: PanelWindow {
            id: deck

            required property var modelData
            readonly property var list: root.slots()
            readonly property bool hovering: dockHover.hovered || stripHover.hovered
            readonly property bool busy: B.screenBusy(Compositor.workspaces, Compositor.windows, deck.modelData.name)
            readonly property bool hidden: B.deckHidden(root.cfg.hide, {
                hovering: deck.hovering,
                menu: menu.visible,
                holding: hideDelay.running,
                busy: deck.busy
            })
            property real pointer: -1
            property real reveal: deck.hidden ? 0 : 1

            screen: modelData
            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: root.size * 1.5 + Tokens.deckPadding * 2 + Tokens.deckMargin + 40
            color: "transparent"
            exclusionMode: root.cfg.hide !== "never" || !root.cfg.reserve ? ExclusionMode.Ignore : ExclusionMode.Normal
            exclusiveZone: root.cfg.hide !== "never" || !root.cfg.reserve ? 0 : root.size + Tokens.deckPadding * 2 + Tokens.deckMargin
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "syldeck"
            mask: Region {
                item: deck.reveal > 0.01 ? dock : strip
            }
            BackgroundEffect.blurRegion: Resin.enabled && deck.reveal > 0.01 ? blur : null

            Behavior on reveal {
                NumberAnimation {
                    duration: Math.round((deck.hidden ? 300 : 460) * Tokens.pace)
                    easing.type: deck.hidden ? Easing.InOutCubic : Easing.OutQuint
                }
            }

            onHoveringChanged: {
                if (!deck.hovering)
                    hideDelay.restart();
            }

            Timer {
                id: hideDelay
                interval: 600
            }

            Region {
                id: blur
                x: dock.x + 1
                y: Math.round(dock.y) + 1
                width: dock.width - 2
                height: Math.max(0, Math.min(dock.height, deck.height - Math.round(dock.y)) - 2)
                radius: Tokens.deckRadius - 1
            }

            Item {
                id: strip
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(4, root.cfg.peek ? root.cfg.peekSize + 6 : 4)

                HoverHandler {
                    id: stripHover
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    visible: root.cfg.peek && opacity > 0
                    width: Math.max(48, dock.width * 0.22) * (stripHover.hovered ? 1.25 : 1)
                    height: root.cfg.peekSize
                    radius: height / 2
                    color: stripHover.hovered ? Theme.accentHi : Theme.accent
                    opacity: (1 - deck.reveal) * 0.85

                    Behavior on width {
                        NumberAnimation {
                            duration: Tokens.stateDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.enterCurve
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.stateDuration
                        }
                    }
                }
            }

            Item {
                id: dock
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height - height - Tokens.deckMargin + (1 - deck.reveal) * (height + Tokens.deckMargin + 4))
                opacity: Math.min(1, 0.2 + deck.reveal * 1.2)
                width: row.width + Tokens.deckPadding * 2
                height: root.size + Tokens.deckPadding * 2

                HoverHandler {
                    id: dockHover
                    onPointChanged: deck.pointer = dockHover.hovered && root.cfg.effect === "magnify" ? dockHover.point.position.x - Tokens.deckPadding : -1
                    onHoveredChanged: {
                        if (!hovered)
                            deck.pointer = -1;
                    }
                }

                Glass {
                    anchors.fill: parent
                    radius: Tokens.deckRadius
                    flowing: false
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Rectangle {
                    x: Tokens.deckRadius
                    width: parent.width - Tokens.deckRadius * 2
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.alpha(Theme.accentHi, 0.55)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }

                Row {
                    id: row
                    x: Tokens.deckPadding
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.deckPadding
                    spacing: 6

                    Repeater {
                        model: deck.list

                        delegate: Item {
                            id: slot
                            required property var modelData
                            required property int index
                            readonly property real rest: slot.index * (root.size + row.spacing) + root.size / 2
                            readonly property bool fixed: slot.modelData.kind !== "app"
                            readonly property real scaleNow: deck.pointer < 0 || slot.fixed ? 1 : B.magnify(slot.rest - deck.pointer, root.reach)
                            readonly property real bloom: root.cfg.effect === "bloom" && !slot.fixed && tileArea.containsMouse ? 1 : 0
                            readonly property var appItem: slot.modelData.kind === "app" ? slot.modelData.item : null
                            readonly property var appEntry: slot.appItem === null ? null : root.entry(slot.appItem.id)
                            readonly property bool focused: slot.appItem !== null && slot.appItem.windows.some(i => root.windows[i].activated)

                            width: slot.modelData.kind === "gap" ? 14 : root.size * slot.scaleNow
                            height: root.size * slot.scaleNow
                            anchors.bottom: parent.bottom

                            Behavior on width {
                                enabled: deck.pointer < 0
                                NumberAnimation {
                                    duration: Tokens.stateDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Tokens.enterCurve
                                }
                            }

                            Column {
                                visible: slot.modelData.kind === "gap"
                                anchors.centerIn: parent
                                spacing: root.size * 0.12

                                Repeater {
                                    model: 3

                                    delegate: Rectangle {
                                        required property int index
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: index === 1 ? 5 : 3
                                        height: width
                                        rotation: 45
                                        antialiasing: true
                                        color: Qt.alpha(index === 1 ? Theme.accent : Theme.text, index === 1 ? 0.8 : 0.3)
                                    }
                                }
                            }

                            Shape {
                                id: glow
                                visible: opacity > 0
                                opacity: slot.bloom
                                anchors.centerIn: parent
                                width: root.size * 1.5
                                height: width
                                preferredRendererType: Shape.CurveRenderer

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration + 80
                                    }
                                }

                                ShapePath {
                                    strokeWidth: -1
                                    fillGradient: RadialGradient {
                                        centerX: glow.width / 2
                                        centerY: glow.height / 2
                                        focalX: glow.width / 2
                                        focalY: glow.height / 2
                                        centerRadius: glow.width / 2
                                        GradientStop {
                                            position: 0
                                            color: Qt.alpha(Theme.accent, 0.45)
                                        }
                                        GradientStop {
                                            position: 1
                                            color: "transparent"
                                        }
                                    }

                                    PathAngleArc {
                                        centerX: glow.width / 2
                                        centerY: glow.height / 2
                                        radiusX: glow.width / 2
                                        radiusY: glow.height / 2
                                        startAngle: 0
                                        sweepAngle: 360
                                    }
                                }
                            }

                            Item {
                                id: tile
                                visible: slot.modelData.kind !== "gap"
                                anchors.fill: parent
                                scale: tileArea.pressed ? 0.88 : 1 + 0.1 * slot.bloom

                                transform: Translate {
                                    y: -7 * slot.bloom
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration + 60
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Tokens.springCurve
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    visible: slot.modelData.kind === "power"

                                    Glass {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: width / 2
                                        inner: true
                                        hot: tileArea.containsMouse
                                        offBorder: Theme.cardLine
                                    }

                                    Glyph {
                                        anchors.centerIn: parent
                                        text: Icons.GLYPHS.power
                                        size: parent.height * 0.4
                                        color: tileArea.containsMouse ? Theme.danger : Theme.text

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Tokens.stateDuration
                                            }
                                        }
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    visible: slot.modelData.kind === "pad"

                                    Glass {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: Tokens.radiusCard
                                        inner: true
                                        lit: root.padOpen
                                        offBorder: Theme.cardLine
                                    }

                                    Glyph {
                                        anchors.centerIn: parent
                                        text: Icons.GLYPHS.apps
                                        size: parent.height * 0.42
                                        color: root.padOpen ? Theme.onAccent : Theme.text
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    visible: slot.appItem !== null && icon.status !== Image.Ready
                                    radius: Tokens.radiusCard
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0
                                            color: Theme.accentHi
                                        }
                                        GradientStop {
                                            position: 1
                                            color: Theme.accentDeep
                                        }
                                    }

                                    Text {
                                        textFormat: Text.PlainText
                                        anchors.centerIn: parent
                                        text: slot.appItem === null ? "" : root.nameOf(slot.appItem.id).charAt(0).toUpperCase()
                                        color: Theme.onAccent
                                        font.family: Tokens.fontUi
                                        font.pixelSize: parent.height * 0.45
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Image {
                                    id: icon
                                    anchors.fill: parent
                                    visible: slot.appItem !== null
                                    source: Apps.icon(slot.appEntry)
                                    layer.enabled: Tokens.iconTint
                                    layer.effect: IconTint {}
                                    sourceSize.width: root.size * 3
                                    sourceSize.height: root.size * 3
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }

                                MouseArea {
                                    id: tileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        if (slot.modelData.kind === "pad") {
                                            root.request("pad", "", deck.modelData);
                                        } else if (slot.modelData.kind === "power") {
                                            root.request("power", "", deck.modelData);
                                        } else if (mouse.button === Qt.RightButton) {
                                            menu.popupFor(slot);
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            Apps.launch(slot.appEntry);
                                        } else {
                                            root.click(slot.appItem);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                readonly property int count: slot.appItem === null ? 0 : slot.appItem.windows.length
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                anchors.topMargin: 3
                                width: count === 0 ? 0 : slot.focused ? root.size * 0.46 : count > 1 ? 14 : 6
                                height: 3
                                radius: 1.5
                                opacity: count === 0 ? 0 : 1
                                color: slot.focused ? Theme.accent : Qt.alpha(Theme.text, 0.55)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Tokens.moveDuration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Tokens.springCurve
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }
                            }

                            Item {
                                opacity: tileArea.containsMouse && !menu.visible && slot.modelData.kind !== "gap" ? 1 : 0
                                visible: opacity > 0
                                scale: 0.9 + 0.1 * opacity

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 12 + 7 * slot.bloom
                                width: tipText.implicitWidth + 22
                                height: 28

                                Glass {
                                    anchors.fill: parent
                                    radius: height / 2
                                    raised: true
                                    offColor: Theme.surface
                                    offBorder: Theme.line
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: slot.modelData.kind === "pad" ? "Apps" : slot.modelData.kind === "power" ? "Power" : slot.appItem === null ? "" : root.nameOf(slot.appItem.id)
                                    color: Theme.text
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.smallSize
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }

            PopupWindow {
                id: menu

                property var slot: null
                readonly property var appItem: menu.slot === null ? null : menu.slot.appItem
                readonly property var rows: menu.appItem === null ? [] : root.menuRows(menu.appItem)

                function popupFor(s: var): void {
                    menu.slot = s;
                    const p = s.mapToItem(null, s.width / 2, 0);
                    menu.anchor.rect.x = p.x - menu.implicitWidth / 2;
                    menu.anchor.rect.y = p.y - menu.implicitHeight - 12;
                    menu.visible = true;
                }

                property real phase: 0

                anchor.window: deck
                implicitWidth: Tokens.deckMenuWidth
                implicitHeight: menuColumn.implicitHeight + 16
                color: "transparent"
                grabFocus: true
                onVisibleChanged: {
                    if (visible) {
                        menu.phase = 0;
                        menuIn.restart();
                    }
                }

                NumberAnimation {
                    id: menuIn
                    target: menu
                    property: "phase"
                    to: 1
                    duration: Tokens.enterDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.enterCurve
                }

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusCard
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                    opacity: menu.phase
                    scale: 0.92 + 0.08 * menu.phase
                    transformOrigin: Item.Bottom
                }

                Column {
                    id: menuColumn
                    opacity: menu.phase
                    scale: 0.92 + 0.08 * menu.phase
                    transformOrigin: Item.Bottom
                    x: 8
                    y: 8
                    width: parent.width - 16

                    Repeater {
                        model: menu.rows

                        delegate: Item {
                            required property var modelData
                            width: menuColumn.width
                            height: modelData.kind === "line" ? 9 : modelData.kind === "title" ? 30 : 34

                            Rectangle {
                                visible: modelData.kind === "line"
                                anchors.centerIn: parent
                                width: parent.width - 16
                                height: 1
                                color: Qt.alpha(Theme.text, 0.12)
                            }

                            Glass {
                                visible: modelData.kind === "action"
                                anchors.fill: parent
                                radius: Tokens.radiusRow - 4
                                inner: true
                                opacity: rowArea.containsMouse ? 1 : 0
                                offBorder: "transparent"
                            }

                            Glyph {
                                id: rowGlyph
                                visible: modelData.kind === "action" && modelData.glyph !== ""
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.glyph || ""
                                size: 15
                                color: Theme.accent
                            }

                            Text {
                                textFormat: Text.PlainText
                                x: modelData.kind === "action" && modelData.glyph !== "" ? 38 : 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - 12
                                visible: modelData.kind !== "line"
                                text: modelData.text || ""
                                elide: Text.ElideRight
                                color: modelData.kind === "title" ? Theme.textDim : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: modelData.kind === "title" ? Tokens.tinySize : Tokens.smallSize
                                font.weight: modelData.kind === "title" ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                enabled: modelData.kind === "action"
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    menu.visible = false;
                                    modelData.run();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function menuRows(it: var): var {
        const rows = [
            {
                kind: "title",
                text: root.nameOf(it.id).toUpperCase()
            }
        ];
        for (const i of it.windows) {
            const w = root.windows[i];
            rows.push({
                kind: "action",
                glyph: "",
                text: w.title || w.appId,
                run: () => Compositor.activate(w)
            });
        }
        if (it.windows.length > 0)
            rows.push({
                kind: "line"
            });
        const e = root.entry(it.id);
        if (e)
            rows.push({
                kind: "action",
                glyph: Icons.GLYPHS.newWindow,
                text: it.windows.length > 0 ? "New window" : "Open",
                run: () => Apps.launch(e)
            });
        rows.push({
            kind: "action",
            glyph: it.pinned ? Icons.GLYPHS.pinOff : Icons.GLYPHS.pin,
            text: it.pinned ? "Remove from Deck" : "Keep in Deck",
            run: () => root.pin(it.id)
        });
        if (it.windows.length > 0)
            rows.push({
                kind: "action",
                glyph: Icons.GLYPHS.close,
                text: it.windows.length > 1 ? "Close " + it.windows.length + " windows" : "Close",
                run: () => it.windows.map(i => root.windows[i]).forEach(w => Compositor.closeWindow(w))
            });
        return rows;
    }
}
