import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/pad.mjs" as P
import "../lib/preview.mjs" as W
import "../lib/icons.mjs" as Icons
import "../lib/bar.mjs" as B

Scope {
    id: root

    property bool shown: false
    property bool wanted: false
    property var screenInfo: null
    property real reveal: 0
    property string query: ""
    property int selected: -1
    property real wheelAcc: 0
    property var tiles: []
    readonly property int columns: Settings.values.pad.columns
    property int fitRows: 8
    readonly property int rows: Math.max(1, Math.min(Settings.values.pad.rows, root.fitRows))
    readonly property int perPage: root.columns * root.rows
    property var pickItems: null
    property string pickOut: ""
    property string pickPrompt: ""
    readonly property bool picking: root.pickItems !== null
    readonly property var results: P.search(root.picking ? root.pickItems : Apps.list.concat(root.tiles), root.query)
    readonly property var pageList: P.pages(root.results, root.perPage)
    property int page: 0
    readonly property bool listMode: root.picking || Settings.values.pad.mode === "list"
    property int wave: 0

    function phase(a: real, b: real): real {
        const t = Math.max(0, Math.min(1, (root.reveal - a) / (b - a)));
        return 1 - Math.pow(1 - t, 3);
    }

    function handleKey(event: var): void {
        const keys = {
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_PageUp]: "pageUp",
            [Qt.Key_PageDown]: "pageDown"
        };
        if (event.key === Qt.Key_Escape) {
            if (root.query !== "")
                root.query = "";
            else
                root.close();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const i = root.selected >= 0 ? root.selected : root.listMode && root.results.length > 0 ? 0 : -1;
            if (i >= 0)
                root.launch(root.results[i]);
        } else if (root.listMode && (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) {
            const d = event.key === Qt.Key_Up ? -1 : 1;
            root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + d));
        } else if (!root.listMode && keys[event.key] !== undefined) {
            const from = root.selected < 0 ? root.page * root.perPage - (keys[event.key] === "right" ? 1 : 0) : root.selected;
            root.select(P.move(Math.max(0, from), keys[event.key], root.results.length, root.columns, root.perPage));
        } else {
            return;
        }
        event.accepted = true;
    }

    signal opened
    signal settingsRequested(string section)

    FileView {
        id: pickFile
        blockLoading: true
        printErrors: false
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
            root.selected = root.listMode ? 0 : -1;
            root.shown = true;
            root.page = 0;
            hideAnim.stop();
            showAnim.restart();
            root.opened();
        });
    }

    function pick(inFile: string, outFile: string, prompt: string): void {
        root.answer("");
        pickFile.path = inFile;
        pickFile.reload();
        root.pickItems = P.pickItems(pickFile.text());
        root.pickOut = outFile;
        root.pickPrompt = prompt;
        if (root.wanted) {
            root.query = "";
            root.selected = 0;
        } else {
            root.open();
        }
    }

    function answer(text: string): void {
        if (root.pickOut === "")
            return;
        Stack.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sylvaris-pick", text, root.pickOut]);
        root.pickOut = "";
        root.pickItems = null;
    }

    function close(): void {
        root.answer("");
        root.wanted = false;
        if (!root.shown)
            return;
        showAnim.stop();
        hideAnim.restart();
    }

    function toggleOn(screen: var): void {
        if (root.wanted) {
            root.close();
            return;
        }
        root.wanted = true;
        root.screenInfo = screen;
        root.query = "";
        root.selected = root.listMode ? 0 : -1;
        root.shown = true;
        root.page = 0;
        hideAnim.stop();
        showAnim.restart();
        root.opened();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open();
    }

    function launch(app: var): void {
        if (app.pick !== undefined)
            root.answer(app.pick);
        root.close();
        if (app.section !== undefined)
            root.settingsRequested(app.section);
        else
            Apps.launch(app);
    }

    function select(index: int): void {
        root.selected = index;
        if (index >= 0)
            root.page = Math.floor(index / root.perPage);
    }

    function turn(delta: int): void {
        root.page = Math.max(0, Math.min(root.pageList.length - 1, root.page + delta));
        if (root.selected >= 0)
            root.selected = Math.min(root.results.length - 1, root.page * root.perPage);
    }

    onQueryChanged: {
        root.select(root.query === "" && !root.listMode || root.results.length === 0 ? -1 : 0);
        root.wave++;
    }

    NumberAnimation {
        id: showAnim
        target: root
        property: "reveal"
        to: 1
        duration: Math.round(760 * Tokens.pace)
    }

    NumberAnimation {
        id: hideAnim
        target: root
        property: "reveal"
        to: 0
        duration: Tokens.exitDuration + 80
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
        onFinished: root.shown = false
    }

    onShownChanged: {
        if (!root.shown)
            keep.restart();
    }

    Timer {
        id: keep
        interval: 20000
    }

    LazyLoader {
        active: root.shown || keep.running

        PanelWindow {
            id: win
            visible: root.shown
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
            WlrLayershell.namespace: "sylpad"
            WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            BackgroundEffect.blurRegion: root.listMode && Resin.enabled && root.reveal > 0.05 ? listBlur : null

            Region {
                id: listBlur
                readonly property real s: listPanel.scale
                x: Math.round(listPanel.x + listPanel.width * (1 - s) / 2)
                y: Math.round(listPanel.y + listPanel.height * (1 - s) / 2)
                width: Math.round(listPanel.width * s)
                height: Math.round(listPanel.height * s)
                radius: Tokens.radiusPanel * s
            }

            onVisibleChanged: {
                if (!visible)
                    return;
                if (root.listMode)
                    listSearch.forceActiveFocus();
                else
                    search.forceActiveFocus();
            }
            Component.onCompleted: {
                if (!visible)
                    return;
                if (root.listMode)
                    listSearch.forceActiveFocus();
                else
                    search.forceActiveFocus();
            }

            Item {
                id: backdrop
                anchors.fill: parent
                visible: !root.listMode

                Backdrop {
                    anchors.fill: parent
                    reveal: root.reveal
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: root.listMode
                onClicked: root.close()

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha("#000000", 0.28 * root.phase(0, 0.4))
                }
            }

            Item {
                id: stage
                anchors.fill: parent
                visible: !root.listMode
                opacity: hideAnim.running ? root.reveal : 1
                scale: hideAnim.running ? 0.94 + 0.06 * root.reveal : 1

                Item {
                    id: searchBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.07) - 40 * (1 - root.phase(0.1, 0.5))
                    opacity: root.phase(0.1, 0.5)
                    width: Tokens.padSearchWidth * (0.85 + 0.15 * root.phase(0.1, 0.5))
                    height: Tokens.padSearchHeight

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                        inner: true
                        offBorder: Theme.cardLine
                    }

                    Glyph {
                        id: searchGlyph
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS.search
                        size: 18
                        color: Theme.textDim
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: searchGlyph.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Search"
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                    }

                    TextInput {
                        id: search
                        anchors.left: searchGlyph.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                        clip: true
                        text: root.query
                        onTextEdited: root.query = text

                        Keys.onPressed: event => root.handleKey(event)
                    }
                }

                ListView {
                    id: pagesView
                    onHeightChanged: {
                        if (height > 0)
                            root.fitRows = Math.max(1, Math.floor(height / Tokens.padCellHeight));
                    }
                    anchors.top: searchBox.bottom
                    anchors.topMargin: Math.round(parent.height * 0.05)
                    anchors.bottom: dots.top
                    anchors.bottomMargin: 24
                    width: parent.width
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: Tokens.moveDuration
                    boundsBehavior: Flickable.StopAtBounds
                    clip: false
                    model: root.pageList
                    currentIndex: root.page
                    onCurrentIndexChanged: root.page = currentIndex

                    delegate: Item {
                        id: pageItem
                        required property var modelData
                        required property int index
                        width: pagesView.width
                        height: pagesView.height

                        Grid {
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: root.columns
                            readonly property real cellW: Math.min(pagesView.width * 0.8 / root.columns, Tokens.padCellWidth)
                            readonly property real cellH: Math.min(Tokens.padCellHeight, pagesView.height / root.rows)

                            Repeater {
                                model: pageItem.modelData
                                delegate: Item {
                                    id: cell
                                    required property var modelData
                                    required property int index
                                    readonly property int flat: pageItem.index * root.perPage + index
                                    readonly property bool current: root.selected === cell.flat
                                    readonly property real col: cell.index % root.columns - (root.columns - 1) / 2
                                    readonly property real row: Math.floor(cell.index / root.columns) - (root.rows - 1) / 2
                                    readonly property real ring: Math.sqrt(cell.col * cell.col + cell.row * cell.row) / Math.sqrt(Math.pow(root.columns / 2, 2) + Math.pow(root.rows / 2, 2))
                                    readonly property real arrive: root.phase(0.2 + 0.35 * cell.ring, 0.62 + 0.35 * cell.ring)
                                    property real pop: 1
                                    width: parent.cellW
                                    height: parent.cellH
                                    opacity: cell.arrive * cell.pop
                                    scale: (0.6 + 0.4 * cell.arrive) * (0.85 + 0.15 * cell.pop)

                                    transform: Translate {
                                        x: cell.col * 26 * (1 - cell.arrive)
                                        y: cell.row * 26 * (1 - cell.arrive) + 18 * (1 - cell.arrive)
                                    }

                                    Connections {
                                        target: root
                                        function onWaveChanged() {
                                            popAnim.restart();
                                        }
                                    }

                                    NumberAnimation {
                                        id: popAnim
                                        target: cell
                                        property: "pop"
                                        from: 0
                                        to: 1
                                        duration: Tokens.enterDuration + Math.round(cell.ring * 160 * Tokens.pace)
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Tokens.enterCurve
                                    }

                                    Item {
                                        anchors.centerIn: parent
                                        width: Tokens.padIcon + 44
                                        height: Tokens.padIcon + 62

                                        Glass {
                                            anchors.fill: parent
                                            radius: Tokens.radiusCard
                                            inner: true
                                            lit: false
                                            opacity: cell.current || area.containsMouse ? 1 : 0
                                            offBorder: Theme.cardLine

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Tokens.stateDuration
                                                }
                                            }
                                        }

                                        Item {
                                            id: iconBox
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 12
                                            width: Tokens.padIcon
                                            height: Tokens.padIcon
                                            scale: area.pressed ? 0.92 : area.containsMouse || cell.current ? 1.06 : 1

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: Tokens.stateDuration
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: Tokens.enterCurve
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                visible: appIcon.status !== Image.Ready
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
                                                    text: cell.modelData.glyph || cell.modelData.name.charAt(0).toUpperCase()
                                                    color: Theme.onAccent
                                                    font.family: cell.modelData.glyph ? Tokens.fontMono : Tokens.fontUi
                                                    font.pixelSize: Tokens.padIcon * 0.42
                                                    font.weight: Font.DemiBold
                                                }
                                            }

                                            Image {
                                                id: appIcon
                                                anchors.fill: parent
                                                source: Apps.icon(cell.modelData)
                                                layer.enabled: Tokens.iconTint
                                                layer.effect: IconTint {}
                                                sourceSize.width: Tokens.padIcon * 2
                                                sourceSize.height: Tokens.padIcon * 2
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                mipmap: true
                                            }
                                        }

                                        Text {
                                            textFormat: Text.PlainText
                                            anchors.top: iconBox.bottom
                                            anchors.topMargin: 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.width - 8
                                            horizontalAlignment: Text.AlignHCenter
                                            text: cell.modelData.name
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            color: Theme.text
                                            style: Text.Raised
                                            styleColor: Qt.alpha("#000000", 0.35)
                                            font.family: Tokens.fontUi
                                            font.pixelSize: Tokens.smallSize
                                            font.weight: Font.Medium
                                        }

                                        Glyph {
                                            visible: Settings.values.deck.pinned.indexOf(cell.modelData.id) >= 0
                                            anchors.right: iconBox.right
                                            anchors.top: iconBox.top
                                            anchors.margins: -4
                                            text: Icons.GLYPHS.pin
                                            size: 16
                                            color: Theme.accent
                                        }

                                        MouseArea {
                                            id: area
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton)
                                                    root.launch(cell.modelData);
                                                else if (cell.modelData.section === undefined)
                                                    Settings.set("deck.pinned", B.togglePin(Settings.values.deck.pinned, cell.modelData.id));
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    WheelHandler {
                        onWheel: event => {
                            const r = W.wheelStep(root.wheelAcc, event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x);
                            root.wheelAcc = r.acc;
                            if (r.steps !== 0)
                                root.turn(r.steps > 0 ? 1 : -1);
                        }
                    }
                }

                Column {
                    anchors.centerIn: pagesView
                    visible: root.results.length === 0
                    spacing: 8

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.query === "" ? "No applications found" : "Nothing matches “" + root.query + "”"
                        color: Theme.text
                        font.family: Tokens.fontDisplay
                        font.pixelSize: Tokens.titleSize
                        font.weight: Tokens.titleWeight
                    }
                }

                Row {
                    id: dots
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(parent.height * 0.06) - 30 * (1 - root.phase(0.55, 0.95))
                    opacity: root.phase(0.55, 0.95)
                    spacing: 10
                    visible: root.pageList.length > 1

                    Repeater {
                        model: root.pageList.length
                        delegate: Rectangle {
                            required property int index
                            width: index === root.page ? 26 : 9
                            height: 9
                            radius: 4.5
                            color: index === root.page ? Theme.accent : Qt.alpha(Theme.text, 0.35)

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

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.page = index
                            }
                        }
                    }
                }
            }
    
            Item {
                id: listPanel
                visible: root.listMode
                anchors.centerIn: parent
                width: Tokens.padListWidth
                height: listSearchBox.height + Math.min(root.results.length, 8) * Tokens.padListRow + 36 + (root.results.length === 0 ? 60 : 0)
                opacity: Math.min(1, root.reveal * 1.6)
                scale: 0.94 + 0.06 * root.reveal

                transform: Translate {
                    y: (1 - root.reveal) * -12
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Tokens.moveDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.moveCurve
                    }
                }

                MouseArea {
                    anchors.fill: parent
                }

                Glass {
                    role: "pad"
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Item {
                    id: listSearchBox
                    x: 14
                    y: 14
                    width: parent.width - 28
                    height: Tokens.padSearchHeight

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusRow
                        inner: true
                        offBorder: Theme.cardLine
                    }

                    Glyph {
                        id: listGlyph
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS.search
                        size: 18
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: listGlyph.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: listSearch.text === ""
                        text: root.picking ? root.pickPrompt || "Pick one" : "Run an application"
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                    }

                    TextInput {
                        id: listSearch
                        anchors.left: listGlyph.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                        clip: true
                        text: root.query
                        onTextEdited: root.query = text
                        Keys.onPressed: event => root.handleKey(event)
                    }
                }

                ListView {
                    id: listView
                    x: 14
                    anchors.top: listSearchBox.bottom
                    anchors.topMargin: 10
                    width: parent.width - 28
                    height: Math.min(root.results.length, 8) * Tokens.padListRow
                    clip: true
                    model: root.results
                    currentIndex: root.selected
                    highlightMoveDuration: Tokens.stateDuration + 40
                    highlightFollowsCurrentItem: true
                    boundsBehavior: Flickable.StopAtBounds

                    highlight: Item {
                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusRow
                            inner: true
                            lit: true
                            litColor: Qt.alpha(Theme.accent, 0.3)
                            offBorder: Theme.cardLine
                        }

                        Rectangle {
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height * 0.5
                            radius: 1.5
                            color: Theme.accent
                        }
                    }

                    delegate: Item {
                        id: rowItem
                        required property var modelData
                        required property int index
                        property real pop: 1
                        readonly property real arrive: root.phase(0.15 + 0.05 * Math.min(rowItem.index, 8), 0.6 + 0.05 * Math.min(rowItem.index, 8))
                        width: listView.width
                        height: Tokens.padListRow
                        opacity: rowItem.arrive * rowItem.pop

                        transform: Translate {
                            x: 16 * (1 - rowItem.arrive * rowItem.pop)
                        }

                        Connections {
                            target: root
                            function onWaveChanged() {
                                rowPop.restart();
                            }
                        }

                        NumberAnimation {
                            id: rowPop
                            target: rowItem
                            property: "pop"
                            from: 0
                            to: 1
                            duration: Tokens.enterDuration + Math.min(rowItem.index, 8) * Tokens.staggerStep
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.enterCurve
                        }

                        Rectangle {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: Tokens.r(9)
                            visible: rowIcon.status !== Image.Ready
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
                                text: rowItem.modelData.glyph || rowItem.modelData.name.charAt(0).toUpperCase()
                                color: Theme.onAccent
                                font.family: rowItem.modelData.glyph ? Tokens.fontMono : Tokens.fontUi
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }

                        Image {
                            id: rowIcon
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            source: Apps.icon(rowItem.modelData)
                            layer.enabled: Tokens.iconTint
                            layer.effect: IconTint {}
                            sourceSize.width: 60
                            sourceSize.height: 60
                            smooth: true
                            mipmap: true
                        }

                        Column {
                            anchors.left: rowIcon.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                textFormat: Text.PlainText
                                width: parent.width
                                text: rowItem.modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.bodySize
                                font.weight: rowItem.index === root.selected ? Font.DemiBold : Font.Medium
                            }

                            Text {
                                textFormat: Text.PlainText
                                width: parent.width
                                visible: text !== ""
                                text: rowItem.modelData.genericName || rowItem.modelData.comment || ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.tinySize
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = rowItem.index
                            onClicked: root.launch(rowItem.modelData)
                        }
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    visible: root.results.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: listSearchBox.bottom
                    anchors.topMargin: 26
                    text: "Nothing matches “" + root.query + "”"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                }
            }
        }
    }
}
