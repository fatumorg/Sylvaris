import QtQuick
import Qt.labs.folderlistmodel
import SylStack
import qs
import qs.services
import qs.components
import qs.files
import "../lib/paper.mjs" as W
import "../lib/settings.mjs" as S
import "../lib/icons.mjs" as Icons

Popup {
    id: root

    readonly property var cfg: Settings.values.paper
    readonly property string folderPath: S.expandHome(root.cfg.folder, Stack.env("HOME"))
    readonly property string current: S.expandHome(W.resolve(root.cfg, Theme.currentId, Theme.wallpaper, root.screenInfo ? root.screenInfo.name : ""), Stack.env("HOME"))
    property string scope: "theme"
    property var menuAt: null
    property var menuScreen: null

    namespace: "sylpaper-picker"
    corner: "center"
    panelWidth: Tokens.paperWidth
    panelHeight: Tokens.paperHeight
    dim: 0.25

    function pick(path: string): void {
        if (root.scope === "output" && root.screenInfo) {
            const o = Object.assign({}, root.cfg.outputs);
            o[root.screenInfo.name] = path;
            Settings.set("paper.outputs", o);
        } else {
            const t = Object.assign({}, root.cfg.themes);
            t[Theme.currentId] = path;
            Settings.set("paper.themes", t);
        }
    }

    function reset(): void {
        if (root.scope === "output" && root.screenInfo) {
            const o = Object.assign({}, root.cfg.outputs);
            delete o[root.screenInfo.name];
            Settings.set("paper.outputs", o);
        } else {
            const t = Object.assign({}, root.cfg.themes);
            delete t[Theme.currentId];
            Settings.set("paper.themes", t);
        }
    }

    function set(path: string): void {
        if (path === "")
            throw new Error("usage: paper set <image path>");
        root.pick(S.expandHome(path, Stack.env("HOME")));
    }

    function step(d: int): void {
        const list = [];
        for (let i = 0; i < folder.count; i++)
            list.push(String(folder.get(i, "filePath")));
        if (list.length === 0)
            return;
        const at = list.indexOf(root.current);
        root.pick(list[(at + d + list.length) % list.length]);
    }

    function showMenu(screen: var, x: real, y: real): void {
        desk.menu = null;
        root.menuScreen = screen;
        root.menuAt = {
            screen: screen,
            x: x,
            y: y
        };
    }

    function menu(): void {
        const screen = Compositor.screenFor(Compositor.focusedName());
        if (screen === null)
            throw new Error("there is no screen to show the menu on");
        root.showMenu(screen, screen.width / 2 - 130, screen.height / 2 - 100);
    }

    Variants {
        model: root.cfg.enabled ? Stack.screens : []

        delegate: PaperLayer {
            host: root
        }
    }

    QtObject {
        id: desk

        property var menu: null
        property var keys: ({
                byAction: ({})
            })
        property string dialog: ""
        property string renaming: ""
        property bool asking: false

        signal focusView

        function act(id: string): void {
        }

        function menuOf(at: var, item: var): var {
            const sep = {
                sep: true
            };
            const run = words => () => Ipc.run(words);
            const out = [];
            if (Settings.values.parts.widgets)
                out.push(item("Edit widgets", Icons.GLYPHS.pencil, "", {
                    run: run(["widgets", "edit"])
                }), sep);
            out.push(item("Next wallpaper", Icons.GLYPHS.image, "", {
                run: () => root.step(1),
                enabled: folder.count > 1
            }), item("Choose a wallpaper…", Icons.GLYPHS.image, "", {
                run: () => root.toggleOn(at.screen)
            }), sep, item("Look…", Icons.GLYPHS.palette, "", {
                run: run(["settings", "open", "look"])
            }), item("Settings…", Icons.GLYPHS.tune, "", {
                run: run(["settings", "open"])
            }));
            return out;
        }

        onMenuChanged: {
            if (desk.menu === null)
                Qt.callLater(() => {
                    if (desk.menu === null)
                        root.menuAt = null;
                });
        }
    }

    LazyLoader {
        active: root.menuAt !== null

        PanelWindow {
            screen: root.menuScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylpaper-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            FilesMenu {
                anchors.fill: parent
                files: desk
            }

            Component.onCompleted: desk.menu = {
                x: root.menuAt.x,
                y: root.menuAt.y,
                screen: root.menuAt.screen
            }
        }
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.folderPath
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.avif", "*.jxl", "*.PNG", "*.JPG", "*.JPEG"]
        sortField: FolderListModel.Name
    }

    Item {
        anchors.fill: parent
        anchors.margins: Tokens.panelPaddingX

        Row {
            id: header
            width: parent.width
            spacing: 14
            opacity: Math.min(1, root.phase * 1.5)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.image
                size: 26
                color: Theme.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - resetButton.width - scopeSwitch.width - 42

                Text {
                    textFormat: Text.PlainText
                    text: "SylPaper"
                    color: Theme.text
                    font.family: Tokens.fontDisplay
                    font.pixelSize: Tokens.titleSize + 3
                    font.weight: Tokens.titleWeight
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.scope === "output" && root.screenInfo ? "Only " + root.screenInfo.name + " · " + folder.count + " images in " + root.cfg.folder : "For the " + (Theme.theme.name || Theme.currentId) + " theme · " + folder.count + " images in " + root.cfg.folder
                    elide: Text.ElideMiddle
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }

            Segmented {
                id: scopeSwitch
                anchors.verticalCenter: parent.verticalCenter
                width: 250
                options: [
                    {
                        key: "theme",
                        label: "This theme"
                    },
                    {
                        key: "output",
                        label: "This screen"
                    }
                ]
                current: root.scope
                onPicked: key => root.scope = key
            }

            RowButton {
                id: resetButton
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                label: "Use default"
                onClicked: root.reset()
            }
        }

        GridView {
            id: grid
            anchors.top: header.bottom
            anchors.topMargin: 18
            anchors.bottom: controls.top
            anchors.bottomMargin: 18
            width: parent.width
            clip: true
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.round(cellWidth * 0.66)
            model: folder
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell
                required property string filePath
                required property string fileBaseName
                required property int index
                readonly property bool on: cell.filePath === root.current
                readonly property real arrive: Math.max(0, Math.min(1, root.phase * 2.2 - Math.min(cell.index, 12) * 0.08))
                width: grid.cellWidth
                height: grid.cellHeight
                opacity: cell.arrive
                scale: (0.9 + 0.1 * cell.arrive) * (thumbArea.pressed ? 0.95 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.springCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Tokens.radiusCard
                    color: Theme.tint
                    border.width: cell.on ? 3 : thumbArea.containsMouse ? 2 : 1
                    border.color: cell.on ? Theme.accent : thumbArea.containsMouse ? Qt.alpha(Theme.accent, 0.6) : Theme.cardLine

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Tokens.stateDuration
                        }
                    }

                    RoundImage {
                        anchors.fill: parent
                        anchors.margins: cell.on ? 5 : 3
                        radius: Tokens.radiusCard - 4
                        source: "file://" + cell.filePath
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        height: 30
                        radius: Tokens.radiusCard - 4
                        color: Qt.alpha("#000000", 0.45)
                        opacity: thumbArea.containsMouse || cell.on ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Tokens.stateDuration
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.fileBaseName
                            elide: Text.ElideMiddle
                            color: "#ffffff"
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.tinySize
                        }
                    }
                }

                MouseArea {
                    id: thumbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pick(cell.filePath)
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: folder.count === 0
                text: "No images in " + root.cfg.folder
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
            }
        }

        Row {
            id: controls
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 12
            opacity: Math.min(1, root.phase * 1.3)

            Slider {
                width: (parent.width - 36 - 260) / 3
                icon: Icons.GLYPHS.fog
                label: "Blur"
                value: root.cfg.blur
                onMoved: v => Settings.set("paper.blur", Math.round(v * 100) / 100)
            }

            Slider {
                width: (parent.width - 36 - 260) / 3
                icon: Icons.GLYPHS.night
                label: "Dim"
                value: root.cfg.dim / 0.9
                onMoved: v => Settings.set("paper.dim", Math.round(v * 90) / 100)
            }

            Slider {
                width: (parent.width - 36 - 260) / 3
                icon: Icons.GLYPHS.palette
                label: "Tint"
                value: root.cfg.tint
                onMoved: v => Settings.set("paper.tint", Math.round(v * 100) / 100)
            }

            Segmented {
                width: 260
                options: W.FITS.map(f => ({
                            key: f,
                            label: f.charAt(0).toUpperCase() + f.slice(1)
                        }))
                current: root.cfg.fit
                onPicked: key => Settings.set("paper.fit", key)
            }
        }
    }
}
