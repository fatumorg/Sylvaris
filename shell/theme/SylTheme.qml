import QtQuick
import QtQuick.Effects
import SylStack
import qs
import qs.services
import qs.components
import "../lib/preview.mjs" as P
import "../lib/icons.mjs" as Icons
import "../lib/capture.mjs" as Cap

Scope {
    id: root

    property bool shown: false
    property bool wanted: false
    property var screenInfo: null
    property real wheelAcc: 0
    property real reveal: 0
    readonly property bool live: root.shown || root.reveal > 0
    property real time: 0
    property bool cursorIdle: false
    property point pointer: Qt.point(-1, -1)
    property string shownName: ""
    property string shownDescription: ""
    property string query: ""
    property string previous: ""
    readonly property var ids: Theme.ids.filter(id => root.matches(id))
    property int index: 0
    readonly property string front: root.index >= 0 && root.index < root.ids.length ? root.ids[root.index] : ""
    readonly property var frontEntry: root.front !== "" && Theme.catalog[root.front] !== undefined ? Theme.catalog[root.front] : null
    readonly property string frontName: root.frontEntry === null ? "" : root.frontEntry.name

    signal opened
    signal jumped
    signal stepped(int delta)
    signal nameSwapped

    function matches(id: string): bool {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return true;
        const e = Theme.catalog[id];
        const name = e === undefined ? id : e.name;
        return id.toLowerCase().indexOf(q) >= 0 || String(name).toLowerCase().indexOf(q) >= 0 || (e !== undefined && String(e.description || "").toLowerCase().indexOf(q) >= 0);
    }

    function type(event: var): bool {
        if (event.key === Qt.Key_Backspace) {
            root.query = root.query.slice(0, -1);
            return true;
        }
        if (event.text !== "" && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) {
            root.query += event.text;
            return true;
        }
        return false;
    }

    function phase(a: real, b: real): real {
        const t = Math.max(0, Math.min(1, (root.reveal - a) / (b - a)));
        return 1 - Math.pow(1 - t, 3);
    }

    function open(): void {
        if (root.wanted)
            return;
        root.wanted = true;
        Compositor.refresh(() => {
            if (!root.wanted)
                return;
            root.screenInfo = Compositor.screenFor(Compositor.focusedName());
            root.query = "";
            const i = root.ids.indexOf(Theme.currentId);
            root.index = Math.max(0, i);
            root.jumped();
            ThemePreview.begin(Theme.currentId);
            root.wheelAcc = 0;
            root.cursorIdle = false;
            idleTimer.restart();
            root.pointer = Qt.point(-1, -1);
            root.shownName = root.frontName;
            root.shownDescription = root.frontEntry === null ? "" : root.frontEntry.description;
            root.shown = true;
            revealOut.stop();
            revealIn.restart();
            root.opened();
        });
    }

    function finish(): void {
        root.wanted = false;
        if (!root.shown)
            return;
        root.shown = false;
        revealIn.stop();
        revealOut.restart();
    }

    function commit(): void {
        if (!root.shown)
            return;
        ThemePreview.commit(root.front);
        root.finish();
    }

    function cancel(): void {
        if (root.shown)
            ThemePreview.cancel();
        root.finish();
    }

    function close(): void {
        root.cancel();
    }

    function toggle(): void {
        if (root.wanted)
            root.cancel();
        else
            root.open();
    }

    function step(delta: int): void {
        if (!root.shown || root.ids.length < 2)
            return;
        root.stepped(delta);
    }

    onQueryChanged: {
        if (root.ids.length > 0)
            root.index = 0;
    }

    onFrontChanged: {
        if (root.front !== "")
            root.previous = root.front;
    }

    onFrontNameChanged: {
        if (root.shown)
            root.nameSwapped();
        else
            root.shownName = root.frontName;
    }

    NumberAnimation {
        id: revealIn
        target: root
        property: "reveal"
        to: 1
        duration: Tokens.ms(1500)
    }

    NumberAnimation {
        id: revealOut
        target: root
        property: "reveal"
        to: 0
        duration: Tokens.ms(1100)
    }

    Timer {
        id: idleTimer
        interval: 1200
        onTriggered: root.cursorIdle = true
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
            visible: root.shown || root.reveal > 0
            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "syltheme"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    stage.forceActiveFocus();
            }

            FrameAnimation {
                running: win.visible && !Tokens.lite
                onTriggered: root.time += frameTime
            }

            Connections {
                target: root
                function onNameSwapped() {
                    nameSwap.restart();
                }
            }

            SequentialAnimation {
                id: nameSwap

                ParallelAnimation {
                    NumberAnimation {
                        target: nameColumn
                        property: "slide"
                        to: 40
                        duration: Tokens.ms(140)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.exitCurve
                    }
                    NumberAnimation {
                        target: nameColumn
                        property: "opacity"
                        to: 0
                        duration: Tokens.ms(140)
                    }
                }
                ScriptAction {
                    script: {
                        root.shownName = root.frontName;
                        root.shownDescription = root.frontEntry === null ? "" : root.frontEntry.description;
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: nameColumn
                        property: "slide"
                        from: 40
                        to: 0
                        duration: Tokens.ms(300)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.enterCurve
                    }
                    NumberAnimation {
                        target: nameColumn
                        property: "opacity"
                        to: 1
                        duration: Tokens.ms(300)
                    }
                }
            }

            Item {
                id: backdrop
                anchors.fill: parent
                readonly property bool gpu: backdrop.GraphicsInfo.api !== GraphicsInfo.Software && backdrop.GraphicsInfo.api !== GraphicsInfo.Unknown

                Item {
                    anchors.fill: parent
                    opacity: root.phase(0, 0.18)

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.base
                    }

                    Image {
                        anchors.fill: parent
                        visible: backdrop.gpu
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 2560
                        source: !backdrop.gpu || Theme.wallpaper === "" ? "" : Cap.fileUri(Theme.wallpaper)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: root.phase(0.12, 0.45)
                    color: root.frontEntry === null ? Theme.base : root.frontEntry.colors.base
                }

                Item {
                    anchors.fill: parent
                    opacity: root.phase(0.12, 0.45)

                    Repeater {
                        model: root.ids
                        delegate: Item {
                            id: layerItem
                            required property string modelData
                            readonly property var e: Theme.catalog[modelData] === undefined ? null : Theme.catalog[modelData]
                            anchors.fill: parent
                            opacity: modelData === root.front ? 1 : 0
                            visible: opacity > 0
                            readonly property bool heavy: visible || modelData === root.previous

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Tokens.ms(400)
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: backdrop.gpu && layerItem.e !== null
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: layerItem.e === null ? Theme.base : layerItem.e.colors.base
                                    }
                                    GradientStop {
                                        position: 1
                                        color: layerItem.e === null ? Theme.base : Qt.darker(layerItem.e.colors.accentDeep, 2.2)
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                scale: 1.06 + 0.02 * Math.sin(root.time * 0.11)

                                transform: Translate {
                                    x: 22 * Math.sin(root.time * 0.07)
                                    y: 14 * Math.cos(root.time * 0.05)
                                }

                                Image {
                                    id: wall
                                    cache: true
                                    anchors.fill: parent
                                    anchors.margins: -64
                                    visible: false
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 1280
                                    source: !backdrop.gpu || !layerItem.heavy || Tokens.lite || layerItem.e === null || layerItem.e.wallpaper === "" ? "" : Cap.fileUri(layerItem.e.wallpaper)
                                }

                                MultiEffect {
                                    anchors.fill: wall
                                    visible: backdrop.gpu && wall.status === Image.Ready
                                    source: wall
                                    blurEnabled: true
                                    blur: 1
                                    blurMax: 32
                                    saturation: 0.1
                                    brightness: -0.35
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: backdrop.gpu && wall.status === Image.Ready
                                color: Qt.alpha(layerItem.e === null ? "#000000" : layerItem.e.colors.base, 0.35)
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: Resin.enabled && Resin.tint > 0 && layerItem.e !== null
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: Qt.alpha(layerItem.e === null ? "#000000" : layerItem.e.colors.accent, Resin.tint * 0.6)
                                    }
                                    GradientStop {
                                        position: 0.55
                                        color: "transparent"
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.shown
                    onClicked: root.cancel()
                }
            }

            Item {
                id: stage
                readonly property real k: win.height > 0 ? Math.min(win.width / 2560, win.height / 1440) : 1
                width: 2560
                height: 1440
                scale: stage.k
                transformOrigin: Item.TopLeft
                x: (win.width - 2560 * stage.k) / 2
                y: (win.height - 1440 * stage.k) / 2
                focus: true
                enabled: root.shown

                HoverHandler {
                    cursorShape: root.cursorIdle ? Qt.BlankCursor : Qt.ArrowCursor
                    onPointChanged: {
                        root.cursorIdle = false;
                        idleTimer.restart();
                        root.pointer = point.position;
                    }
                    onHoveredChanged: {
                        if (!hovered)
                            root.pointer = Qt.point(-1, -1);
                    }
                }

                Keys.onLeftPressed: root.step(-1)
                Keys.onRightPressed: root.step(1)
                Keys.onReturnPressed: root.commit()
                Keys.onEnterPressed: root.commit()
                Keys.onEscapePressed: {
                    if (root.query !== "")
                        root.query = "";
                    else
                        root.cancel();
                }
                Keys.onPressed: event => {
                    if (root.type(event))
                        event.accepted = true;
                }

                PathView {
                    id: carousel
                    anchors.fill: parent
                    model: root.ids
                    pathItemCount: Math.min(count, 7)
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: 0
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    highlightMoveDuration: 450
                    snapMode: PathView.SnapOneItem
                    interactive: count > 1
                    onCurrentIndexChanged: {
                        root.index = currentIndex;
                        if (root.shown && currentIndex >= 0 && currentIndex < root.ids.length)
                            ThemePreview.settle(root.ids[currentIndex]);
                    }
                    Component.onCompleted: {
                        carousel.positionViewAtIndex(root.index, PathView.Beginning);
                        carousel.currentIndex = root.index;
                    }

                    Connections {
                        target: root
                        function onIndexChanged() {
                            if (carousel.currentIndex !== root.index)
                                carousel.currentIndex = root.index;
                        }
                        function onJumped() {
                            carousel.positionViewAtIndex(root.index, PathView.Beginning);
                            carousel.currentIndex = root.index;
                        }
                        function onStepped(delta) {
                            if (delta > 0)
                                carousel.incrementCurrentIndex();
                            else
                                carousel.decrementCurrentIndex();
                        }
                    }

                    path: Path {
                        startX: 1280
                        startY: Tokens.themeRingCenterY + Tokens.themeRingY

                        PathAttribute {
                            name: "depth"
                            value: 1
                        }
                        PathAttribute {
                            name: "turn"
                            value: 0
                        }
                        PathArc {
                            x: 1280 + Tokens.themeRingX
                            y: Tokens.themeRingCenterY
                            radiusX: Tokens.themeRingX
                            radiusY: Tokens.themeRingY
                            direction: PathArc.Counterclockwise
                        }
                        PathAttribute {
                            name: "depth"
                            value: 0.775
                        }
                        PathAttribute {
                            name: "turn"
                            value: -28
                        }
                        PathArc {
                            x: 1280
                            y: Tokens.themeRingCenterY - Tokens.themeRingY
                            radiusX: Tokens.themeRingX
                            radiusY: Tokens.themeRingY
                            direction: PathArc.Counterclockwise
                        }
                        PathAttribute {
                            name: "depth"
                            value: 0.55
                        }
                        PathAttribute {
                            name: "turn"
                            value: 0
                        }
                        PathArc {
                            x: 1280 - Tokens.themeRingX
                            y: Tokens.themeRingCenterY
                            radiusX: Tokens.themeRingX
                            radiusY: Tokens.themeRingY
                            direction: PathArc.Counterclockwise
                        }
                        PathAttribute {
                            name: "depth"
                            value: 0.775
                        }
                        PathAttribute {
                            name: "turn"
                            value: 28
                        }
                        PathArc {
                            x: 1280
                            y: Tokens.themeRingCenterY + Tokens.themeRingY
                            radiusX: Tokens.themeRingX
                            radiusY: Tokens.themeRingY
                            direction: PathArc.Counterclockwise
                        }
                    }

                    delegate: ThemeCard {
                        enter: root.phase(0.28 + 0.16 * (1 - depth) / 0.45, 0.66 + 0.16 * (1 - depth) / 0.45)
                        time: root.time
                        pointer: root.pointer
                        onPicked: i => {
                            if (i === carousel.currentIndex)
                                root.commit();
                            else
                                carousel.currentIndex = i;
                        }
                    }

                    TapHandler {
                        onTapped: root.cancel()
                    }

                    WheelHandler {
                        onWheel: event => {
                            const r = P.wheelStep(root.wheelAcc, event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x);
                            root.wheelAcc = r.acc;
                            for (let i = 0; i < Math.abs(r.steps); i++)
                                root.step(r.steps > 0 ? 1 : -1);
                        }
                    }
                }

                Item {
                    id: searchPill
                    x: 140
                    y: 110 - 60 * (1 - root.phase(0.35, 0.8))
                    width: 620 + (root.query !== "" ? 60 : 0)
                    height: 76
                    opacity: root.phase(0.35, 0.8)

                    Behavior on width {
                        NumberAnimation {
                            duration: Tokens.moveDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.springCurve
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                        lit: root.query !== ""
                        litColor: Qt.alpha(Theme.accent, 0.18)
                    }

                    Glyph {
                        id: searchIcon
                        x: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS.search
                        size: 30
                        color: root.query !== "" ? Theme.accent : Theme.textDim
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 18
                        anchors.right: countText.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query !== "" ? root.query : "Type to search themes"
                        elide: Text.ElideLeft
                        color: root.query !== "" ? Theme.text : Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: 28

                        Rectangle {
                            visible: root.query !== ""
                            x: Math.min(parent.width, parent.implicitWidth) + 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 32
                            radius: 1.5
                            color: Theme.accent

                            SequentialAnimation on opacity {
                                running: root.query !== "" && root.shown
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0
                                    duration: Tokens.loopMs(500)
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: Tokens.loopMs(500)
                                }
                            }
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: countText
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ids.length + " / " + Theme.ids.length
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: 22
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    visible: carousel.count === 0
                    anchors.centerIn: parent
                    opacity: root.phase(0.28, 0.66)
                    text: root.query !== "" ? "No theme matches “" + root.query + "”" : "No themes found"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: 48
                }

                Item {
                    x: 140
                    y: 1440 - 170 - nameText.height
                    width: nameColumn.width
                    height: nameColumn.height
                    opacity: root.phase(0.45, 0.86)

                    transform: Translate {
                        y: (1 - root.phase(0.45, 0.86)) * 240
                    }

                    Column {
                        id: nameColumn
                        property real slide: 0
                        spacing: 6

                        transform: Translate {
                            y: nameColumn.slide
                        }

                        Text {
                            textFormat: Text.PlainText
                            id: nameText
                            text: root.shownName
                            color: Qt.alpha(root.frontEntry === null ? Theme.text : root.frontEntry.colors.text, 0.92)
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.themeNameSize
                            font.weight: Font.ExtraBold
                            font.letterSpacing: -6
                            layer.enabled: backdrop.gpu
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowBlur: 0.6
                                shadowOpacity: 0.45
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: root.shownDescription
                            color: root.frontEntry === null ? Theme.textDim : root.frontEntry.colors.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: 28
                        }
                    }
                }

                Item {
                    id: applyButton
                    visible: carousel.count > 0
                    x: 2560 - 140 - width
                    y: 1440 - 140 - height
                    width: applyLabel.implicitWidth + 68
                    height: applyLabel.implicitHeight + 40
                    opacity: root.phase(0.58, 0.94)
                    scale: applyArea.pressed ? 0.96 : applyArea.containsMouse ? 1.03 : 1

                    transform: Translate {
                        y: (1 - root.phase(0.58, 0.94)) * 220
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.ms(140)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.enterCurve
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                        lit: true
                        hot: applyArea.containsMouse
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: applyLabel
                        anchors.centerIn: parent
                        text: "Apply theme"
                        color: Theme.onAccent
                        font.family: Tokens.fontUi
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.commit()
                    }
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1440 - 50 - height
                    width: hint.implicitWidth + 40
                    height: hint.implicitHeight + 16
                    opacity: root.phase(0.66, 1)

                    transform: Translate {
                        y: (1 - root.phase(0.66, 1)) * 180
                    }

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: hint
                        anchors.centerIn: parent
                        text: Theme.hookError !== "" ? Theme.hookError : "◀ ▶ switch · type to search · Enter apply · Esc cancel"
                        color: Theme.hookError !== "" ? Theme.danger : Theme.textSoft
                        font.family: Tokens.fontUi
                        font.pixelSize: 20
                    }
                }
            }

        }
    }
}
