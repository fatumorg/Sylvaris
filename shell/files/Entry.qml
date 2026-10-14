import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F

Item {
    id: root

    required property var files
    required property var entry
    property real radius: Tokens.radiusRow
    readonly property string full: F.joinPath(root.files.path, root.entry.name)
    readonly property bool chosen: root.files.selection[root.entry.name] === true
    readonly property bool cursor: root.files.cursor === root.entry.name
    readonly property bool hovered: area.containsMouse
    readonly property bool dropHot: drop.containsDrag && drop.welcome
    readonly property bool cut: root.files.clip.mode === "cut" && root.files.clip.items.some(i => i.path === root.full)
    readonly property bool faded: root.cut || root.entry.name.charAt(0) === "."

    Glass {
        anchors.fill: parent
        radius: root.radius
        inner: true
        flowing: false
        hot: root.hovered || root.dropHot
        lit: root.chosen || root.dropHot
        opacity: root.chosen || root.hovered || root.dropHot ? 1 : 0
        offColor: root.hovered ? Theme.tintMid : Theme.tintSoft

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1.5
        border.color: Qt.alpha(Theme.accent, 0.8)
        visible: root.cursor && !root.chosen && root.files.selected.length > 0
    }

    Item {
        id: proxy
        width: 1
        height: 1
        Drag.active: area.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.mimeData: ({
                "text/uri-list": root.files.dragUris(root.entry.name)
            })
        Drag.onDragStarted: {
            if (root.files.dragging)
                root.files.dragging(root.entry.name);
        }
        Drag.onDragFinished: {
            proxy.x = 0;
            proxy.y = 0;
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        drag.target: root.files.inTrash ? null : proxy
        drag.threshold: 8
        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton)
                return;
            root.files.press(root.entry.name, mouse.button === Qt.RightButton ? 0 : mouse.modifiers);
            if (mouse.button === Qt.LeftButton && !root.files.inTrash)
                root.grabToImage(r => proxy.Drag.imageSource = r.url, Qt.size(Math.min(root.width, 220), Math.min(root.height, 220)));
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                const p = area.mapToItem(null, mouse.x, mouse.y);
                root.files.contextAt(root.entry.name, p.x, p.y);
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.entry.dir)
                    root.files.activate(root.entry.name, true);
            } else {
                root.files.tap(root.entry.name, mouse.modifiers);
                if (root.files.cfg.click === "single" && !(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)))
                    root.files.activate(root.entry.name, false);
            }
        }
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton && root.files.cfg.click === "double")
                root.files.activate(root.entry.name, false);
        }
    }

    DropArea {
        id: drop
        property bool welcome: false
        anchors.fill: parent
        enabled: root.entry.dir && !root.files.inTrash
        keys: ["text/uri-list"]
        onEntered: d => {
            drop.welcome = d.hasUrls && !d.urls.some(u => F.pathsOfUris(String(u)).indexOf(root.full) >= 0);
            d.accepted = drop.welcome;
        }
        onExited: drop.welcome = false
        onDropped: d => {
            const action = d.proposedAction === Qt.CopyAction || !(d.supportedActions & Qt.MoveAction) ? Qt.CopyAction : Qt.MoveAction;
            root.files.dropped(root.full, d.urls, action);
            d.accept(action);
            drop.welcome = false;
        }
    }
}
