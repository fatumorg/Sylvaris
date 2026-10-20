import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import "../lib/viewer.mjs" as V
import "../lib/icons.mjs" as Icons

Scope {
    id: root

    property bool wanted: false
    property bool shown: false
    property var screenInfo: null
    property real reveal: 0
    property string path: ""
    property var names: []
    property bool arming: false
    property bool choosing: false
    property string note: ""
    property var video: null
    readonly property var cfg: Settings.values.viewer
    readonly property string folder: root.path === "" ? "" : root.path.slice(0, root.path.lastIndexOf("/")) || "/"
    readonly property string name: root.path.slice(root.path.lastIndexOf("/") + 1)
    readonly property string kind: V.kindOf(root.path) || ""
    readonly property bool animated: V.ANIMATED.indexOf(V.extOf(root.path)) >= 0
    readonly property int index: root.names.indexOf(root.name)
    readonly property int count: Math.max(1, root.names.length)
    readonly property var apps: root.choosing ? V.openers(DesktopEntries.applications.values.map(e => ({
                    id: e.id,
                    name: e.name,
                    categories: e.categories,
                    execString: e.execString
                })), root.kind) : []

    signal opened

    function open(arg: string): void {
        const p = V.pathFrom(arg);
        if (p === "")
            throw new Error("usage: viewer open <absolute path or file:// URI>");
        if (V.kindOf(p) === null)
            throw new Error("not an image or video: " + p);
        root.path = p;
        root.arming = false;
        root.choosing = false;
        if (root.wanted)
            return;
        root.wanted = true;
        Compositor.refresh(() => {
            if (root.wanted)
                root.show(Compositor.screenFor(Compositor.focusedName()));
        });
    }

    function show(screen: var): void {
        root.screenInfo = screen;
        root.shown = true;
        hideAnim.stop();
        showAnim.restart();
        root.opened();
    }

    function toggleOn(screen: var): void {
        if (root.wanted) {
            root.close();
            return;
        }
        if (root.path === "")
            return;
        root.wanted = true;
        root.show(screen);
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else if (root.path !== "")
            root.open(root.path);
    }

    function close(): void {
        root.wanted = false;
        root.arming = false;
        root.choosing = false;
        if (root.video !== null)
            root.video.stop();
        if (!root.shown)
            return;
        showAnim.stop();
        hideAnim.restart();
    }

    function step(d: int): void {
        if (root.names.length === 0)
            return;
        const i = V.step(root.names.length, Math.max(0, root.index), root.index < 0 && d > 0 ? 0 : d);
        root.arming = false;
        root.choosing = false;
        root.path = (root.folder === "/" ? "" : root.folder) + "/" + root.names[i];
    }

    function rescan(): void {
        const out = [];
        for (let i = 0; i < files.count; i++)
            out.push(files.get(i, "fileName"));
        root.names = V.order(out);
    }

    function say(text: string): void {
        root.note = text;
        noteTimer.restart();
    }

    function play(): void {
        if (root.video === null)
            throw new Error("nothing to play: the viewer shows no video");
        root.video.toggle();
    }

    function copy(): void {
        if (root.path === "")
            return;
        if (root.kind === "image")
            Quickshell.execDetached(["sh", "-c", "wl-copy -t \"$1\" < \"$2\"", "sh", V.mimeOf(root.path), root.path]);
        else
            Quickshell.execDetached(["wl-copy", "-t", "text/uri-list", V.uriOf(root.path)]);
        root.say(root.kind === "image" ? "Image copied" : "File copied");
    }

    function showFolder(): void {
        if (root.folder === "")
            return;
        Quickshell.execDetached(["gio", "open", root.folder]);
        root.close();
    }

    function wallpaper(): void {
        if (root.kind !== "image")
            throw new Error("only images can be the wallpaper");
        const out = Ipc.run(["paper", "set", root.path]);
        root.say(out.indexOf("error:") === 0 ? out.slice(6).trim() : "Set as wallpaper");
    }

    function openWith(app: var): void {
        const args = V.execArgs(app.execString, root.path);
        if (args.length === 0)
            return;
        Quickshell.execDetached(args);
        root.close();
    }

    function trash(): void {
        if (root.path === "" || trasher.running)
            return;
        if (!root.arming) {
            root.arming = true;
            root.say("Press again to move it to the trash");
            armTimer.restart();
            return;
        }
        root.arming = false;
        trasher.target = root.path;
        trasher.command = ["gio", "trash", "--", root.path];
        trasher.running = true;
    }

    function state(): var {
        return {
            open: root.wanted,
            path: root.path,
            kind: root.kind,
            index: root.index,
            count: root.names.length,
            playing: root.video !== null && root.video.playing,
            position: root.video !== null ? Math.round(root.video.position * 10) / 10 : 0,
            duration: root.video !== null ? Math.round(root.video.duration * 10) / 10 : 0,
            choosing: root.choosing,
            note: root.note
        };
    }

    FolderListModel {
        id: files
        folder: root.folder === "" ? "" : V.uriOf(root.folder)
        nameFilters: V.NAME_FILTERS
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        onStatusChanged: {
            if (files.status === FolderListModel.Ready)
                root.rescan();
        }
        onCountChanged: root.rescan()
    }

    Process {
        id: trasher
        property string target: ""
        onExited: code => {
            if (code !== 0) {
                root.say("Could not move it to the trash");
                return;
            }
            const left = root.names.filter(n => n !== trasher.target.slice(trasher.target.lastIndexOf("/") + 1));
            if (trasher.target !== root.path)
                return;
            if (left.length === 0) {
                root.close();
                return;
            }
            const i = Math.min(Math.max(0, root.index), left.length - 1);
            root.names = left;
            root.path = (root.folder === "/" ? "" : root.folder) + "/" + left[i];
            root.say("Moved to the trash");
        }
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: root.arming = false
    }

    Timer {
        id: noteTimer
        interval: 2200
        onTriggered: root.note = ""
    }

    NumberAnimation {
        id: showAnim
        target: root
        property: "reveal"
        to: 1
        duration: Tokens.enterDuration + 140
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
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

    LazyLoader {
        active: root.shown

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
            WlrLayershell.namespace: "sylviewer"
            WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    stage.forceActiveFocus();
            }
            Component.onCompleted: {
                if (visible)
                    stage.forceActiveFocus();
            }

            Backdrop {
                anchors.fill: parent
                reveal: root.reveal
                dim: 0.55
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.choosing)
                        root.choosing = false;
                    else
                        root.close();
                }
                onWheel: e => root.step(e.angleDelta.y > 0 ? -1 : 1)
            }

            Item {
                id: stage
                anchors.fill: parent
                anchors.topMargin: 88
                anchors.bottomMargin: 112
                anchors.leftMargin: 56
                anchors.rightMargin: 56
                focus: true
                opacity: Math.min(1, root.reveal * 1.4)
                scale: 0.96 + 0.04 * root.reveal

                Keys.onLeftPressed: root.step(-1)
                Keys.onRightPressed: root.step(1)
                Keys.onSpacePressed: {
                    if (root.video !== null)
                        root.video.toggle();
                    else
                        root.step(1);
                }
                Keys.onDeletePressed: root.trash()
                Keys.onEscapePressed: {
                    if (root.choosing)
                        root.choosing = false;
                    else
                        root.close();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_C && event.modifiers & Qt.ControlModifier) {
                        root.copy();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_M && root.kind === "video") {
                        Settings.put("viewer.muted", !root.cfg.muted);
                        event.accepted = true;
                    }
                }

                Item {
                    id: media
                    anchors.fill: parent
                    readonly property real shownW: root.kind !== "image" ? media.width : root.animated ? gif.paintedWidth : still.paintedWidth
                    readonly property real shownH: root.kind !== "image" ? media.height : root.animated ? gif.paintedHeight : still.paintedHeight
                    opacity: 0

                    Connections {
                        target: root

                        function onPathChanged() {
                            media.opacity = 0;
                            appear.restart();
                        }
                    }

                    Component.onCompleted: appear.restart()

                    NumberAnimation {
                        id: appear
                        target: media
                        property: "opacity"
                        to: 1
                        duration: Tokens.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.enterCurve
                    }

                    MouseArea {
                        anchors.centerIn: parent
                        width: media.shownW
                        height: media.shownH
                        onClicked: {
                            if (root.video !== null)
                                root.video.toggle();
                        }
                    }

                    Image {
                        id: still
                        anchors.fill: parent
                        visible: root.kind === "image" && !root.animated
                        source: visible ? V.uriOf(root.path) : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 3840
                        sourceSize.height: 3840
                        smooth: true
                        mipmap: true
                    }

                    AnimatedImage {
                        id: gif
                        anchors.fill: parent
                        visible: root.kind === "image" && root.animated
                        source: visible ? V.uriOf(root.path) : ""
                        playing: root.shown
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Loader {
                        id: videoLoader
                        anchors.fill: parent
                        active: root.kind === "video" && root.shown
                        source: "VideoPane.qml"
                        onLoaded: {
                            item.source = Qt.binding(() => root.kind === "video" ? V.uriOf(root.path) : "");
                            item.autoplay = Qt.binding(() => root.cfg.autoplay);
                            item.loop = Qt.binding(() => root.cfg.loop);
                            item.muted = Qt.binding(() => root.cfg.muted);
                            root.video = item;
                        }
                        onActiveChanged: {
                            if (!active)
                                root.video = null;
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    visible: problem.text !== ""

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.kind === "video" ? Icons.GLYPHS.video : Icons.GLYPHS.image
                        size: 56
                        color: Theme.textDim
                    }

                    Text {
                        id: problem
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        text: root.kind === "image" && (root.animated ? gif.status : still.status) === Image.Error ? "This image cannot be opened" : root.kind === "video" && videoLoader.status === Loader.Error ? "Video needs Qt Multimedia, which this build of Sylvaris does not have" : root.kind === "video" && root.video !== null && root.video.error !== "" ? root.video.error : ""
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                    }
                }
            }

            Item {
                id: head
                x: 24
                y: 24
                width: headRow.implicitWidth + 36
                height: 48
                opacity: root.reveal

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Row {
                    id: headRow
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kind === "video" ? Icons.GLYPHS.video : Icons.GLYPHS.image
                        size: 18
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, win.width * 0.45)
                        textFormat: Text.PlainText
                        text: root.name
                        elide: Text.ElideMiddle
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: counter
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: (root.index < 0 ? 1 : root.index + 1) + " / " + root.count
                        color: Theme.textDim
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.smallSize
                    }
                }
            }

            Item {
                x: win.width - width - 24
                y: 24
                width: 48
                height: 48
                opacity: root.reveal

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                ViewerButton {
                    anchors.centerIn: parent
                    glyph: Icons.GLYPHS.close
                    tip: "Close (Esc)"
                    onClicked: root.close()
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                width: noteText.implicitWidth + 36
                height: 40
                opacity: root.note !== "" ? root.reveal : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.fadeDuration
                    }
                }

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    raised: true
                    offColor: Theme.surface
                    offBorder: root.arming ? Theme.danger : Theme.line
                }

                Text {
                    id: noteText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: root.note
                    color: root.arming ? Theme.danger : Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }
            }

            Item {
                id: menu
                visible: root.choosing
                x: Math.min(bar.x + openBtn.mapToItem(bar, 0, 0).x - 20, win.width - width - 24)
                y: bar.y - height - 12
                width: 280
                height: Math.min(menuCol.implicitHeight + 16, win.height * 0.5)

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusCard
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    contentHeight: menuCol.implicitHeight
                    clip: true

                    Column {
                        id: menuCol
                        width: parent.width
                        spacing: 4

                        Text {
                            visible: root.apps.length === 0
                            width: parent.width
                            padding: 10
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: root.kind === "video" ? "No other video apps are installed" : "No other image apps are installed"
                            color: Theme.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                        }

                        Repeater {
                            model: root.apps

                            RowButton {
                                required property var modelData
                                width: menuCol.width
                                icon: Icons.GLYPHS.open
                                label: modelData.name
                                onClicked: root.openWith(modelData)
                            }
                        }
                    }
                }
            }

            Item {
                id: bar
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.height - height - 28 + (1 - root.reveal) * 24
                width: barRow.implicitWidth + 20
                height: 60
                opacity: root.reveal

                Glass {
                    anchors.fill: parent
                    radius: 22
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                MouseArea {
                    anchors.fill: parent
                }

                Row {
                    id: barRow
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    ViewerButton {
                        glyph: Icons.GLYPHS.previous
                        tip: "Previous (←)"
                        enabled: root.names.length > 1
                        onClicked: root.step(-1)
                    }

                    ViewerButton {
                        glyph: Icons.GLYPHS.next
                        tip: "Next (→)"
                        enabled: root.names.length > 1
                        onClicked: root.step(1)
                    }

                    Row {
                        visible: root.video !== null
                        spacing: 4

                        Rectangle {
                            width: 1
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.alpha(Theme.text, 0.12)
                        }

                        ViewerButton {
                            glyph: root.video !== null && root.video.playing ? Icons.GLYPHS.pause : Icons.GLYPHS.play
                            tip: root.video !== null && root.video.playing ? "Pause (Space)" : "Play (Space)"
                            strong: true
                            onClicked: root.play()
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52
                            horizontalAlignment: Text.AlignRight
                            textFormat: Text.PlainText
                            text: V.clock(root.video !== null ? root.video.position : 0)
                            color: Theme.textDim
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.smallSize
                        }

                        Item {
                            id: seek
                            anchors.verticalCenter: parent.verticalCenter
                            width: 240
                            height: 40
                            readonly property real frac: root.video !== null && root.video.duration > 0 ? Math.min(1, root.video.position / root.video.duration) : 0

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: seekArea.containsMouse || seekArea.pressed ? 6 : 4
                                radius: height / 2
                                color: Qt.alpha(Theme.text, 0.16)

                                Rectangle {
                                    width: parent.width * seek.frac
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.accent
                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Tokens.stateDuration
                                    }
                                }
                            }

                            Rectangle {
                                x: seek.width * seek.frac - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 7
                                visible: seekArea.containsMouse || seekArea.pressed
                                color: Theme.accentHi
                            }

                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: e => root.video.seek(e.x / width)
                                onPositionChanged: e => {
                                    if (pressed)
                                        root.video.seek(e.x / width);
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52
                            textFormat: Text.PlainText
                            text: V.clock(root.video !== null ? root.video.duration : 0)
                            color: Theme.textDim
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.smallSize
                        }

                        ViewerButton {
                            glyph: root.cfg.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume
                            tip: root.cfg.muted ? "Unmute (M)" : "Mute (M)"
                            lit: root.cfg.muted
                            onClicked: Settings.put("viewer.muted", !root.cfg.muted)
                        }

                        ViewerButton {
                            glyph: root.cfg.loop ? Icons.GLYPHS.repeat : Icons.GLYPHS.repeatOff
                            tip: root.cfg.loop ? "Loop is on" : "Loop is off"
                            lit: root.cfg.loop
                            onClicked: Settings.put("viewer.loop", !root.cfg.loop)
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(Theme.text, 0.12)
                    }

                    ViewerButton {
                        glyph: Icons.GLYPHS.copy
                        tip: "Copy (Ctrl+C)"
                        onClicked: root.copy()
                    }

                    ViewerButton {
                        id: openBtn
                        glyph: Icons.GLYPHS.open
                        tip: "Open with"
                        lit: root.choosing
                        onClicked: root.choosing = !root.choosing
                    }

                    ViewerButton {
                        glyph: Icons.GLYPHS.folder
                        tip: "Show in folder"
                        onClicked: root.showFolder()
                    }

                    ViewerButton {
                        glyph: Icons.GLYPHS.image
                        tip: "Set as wallpaper"
                        enabled: root.kind === "image"
                        onClicked: root.wallpaper()
                    }

                    ViewerButton {
                        glyph: Icons.GLYPHS.trash
                        tip: root.arming ? "Press again to confirm (Delete)" : "Move to trash (Delete)"
                        danger: root.arming
                        enabled: !trasher.running
                        onClicked: root.trash()
                    }
                }
            }
        }
    }
}
