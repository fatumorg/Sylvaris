import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/plan.mjs" as P
import "../../lib/icons.mjs" as Icons

Item {
    id: root

    property string selected: ""
    property string naming: ""
    property string namingMode: ""
    property string armed: ""
    readonly property var lists: P.places(Diver.data)
    readonly property string current: root.lists.some(p => p.key === root.selected) ? root.selected : root.lists.length > 0 ? root.lists[0].key : ""
    readonly property var list: {
        if (root.current === "")
            return null;
        try {
            return P.findNode(Diver.data, root.current);
        } catch (e) {
            return null;
        }
    }

    signal edit(string id, string where)
    signal create(string text, string where)
    signal focusTask(string id)
    signal failed(string message)

    function run(fn: var): void {
        try {
            fn();
        } catch (e) {
            root.failed(e.message);
        }
    }

    function startNaming(mode: string, path: string): void {
        root.namingMode = mode;
        root.naming = path;
        root.armed = "";
    }

    function finishNaming(text: string): void {
        const mode = root.namingMode;
        const path = root.naming;
        root.naming = "";
        root.namingMode = "";
        if (text.trim() === "")
            return;
        root.run(() => mode === "add" ? Diver.addNode(path, text) : Diver.renameNode(path, text));
    }

    function removeArmed(path: string): void {
        if (root.armed !== path) {
            root.armed = path;
            return;
        }
        root.armed = "";
        root.run(() => Diver.removeNode(path));
    }

    component NodeRow: Item {
        id: node
        required property string path
        required property string label
        required property int depth
        property bool selectable: false
        property string addLabel: ""
        readonly property bool renaming: root.naming === node.path && root.namingMode === "rename"
        width: parent ? parent.width : 0
        height: 36

        Glass {
            anchors.fill: parent
            radius: Tokens.r(12)
            inner: true
            visible: node.selectable && root.current === node.path || nodeArea.containsMouse
            lit: node.selectable && root.current === node.path
        }

        Text {
            textFormat: Text.PlainText
            x: 10 + node.depth * 14
            width: parent.width - x - tools.width - 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !node.renaming
            text: node.label
            elide: Text.ElideRight
            color: node.selectable && root.current === node.path ? Theme.onAccent : node.depth === 0 ? Theme.text : Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: node.depth === 0 ? Tokens.bodySize : Tokens.smallSize
            font.weight: node.depth === 0 ? Font.DemiBold : Font.Normal
        }

        TextBox {
            x: 4 + node.depth * 14
            width: parent.width - x - 4
            height: 34
            anchors.verticalCenter: parent.verticalCenter
            visible: node.renaming
            Component.onCompleted: text = node.label
            onVisibleChanged: {
                if (visible) {
                    text = node.label;
                    focusInput();
                }
            }
            onAccepted: root.finishNaming(text)
            Keys.onEscapePressed: event => {
                root.naming = "";
                event.accepted = true;
            }
        }

        MouseArea {
            id: nodeArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !node.renaming
            cursorShape: node.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (node.selectable)
                    root.selected = node.path;
            }
        }

        Row {
            id: tools
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: !node.renaming
            opacity: nodeArea.containsMouse || plusArea.containsMouse || penArea.containsMouse || binArea.containsMouse || root.armed === node.path ? 1 : 0

            Glyph {
                visible: node.addLabel !== ""
                width: 26
                height: 26
                text: Icons.GLYPHS.plus
                size: 15
                color: plusArea.containsMouse ? Theme.accent : Theme.textDim

                MouseArea {
                    id: plusArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNaming("add", node.path)
                }
            }

            Glyph {
                width: 26
                height: 26
                text: Icons.GLYPHS.pencil
                size: 14
                color: penArea.containsMouse ? Theme.accent : Theme.textDim

                MouseArea {
                    id: penArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNaming("rename", node.path)
                }
            }

            Glyph {
                width: 26
                height: 26
                text: Icons.GLYPHS.trash
                size: 14
                color: root.armed === node.path ? Theme.danger : binArea.containsMouse ? Theme.text : Theme.textDim

                MouseArea {
                    id: binArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeArmed(node.path)
                }
            }
        }
    }

    component NameBox: TextBox {
        id: box
        required property string parentPath
        required property int depth
        x: 4 + box.depth * 14
        width: parent ? parent.width - x - 4 : 0
        height: 34
        visible: root.naming === box.parentPath && root.namingMode === "add"
        onVisibleChanged: {
            if (visible) {
                text = "";
                focusInput();
            }
        }
        onAccepted: root.finishNaming(text)
        Keys.onEscapePressed: event => {
            root.naming = "";
            event.accepted = true;
        }
    }

    Flickable {
        id: tree
        width: 320
        height: parent.height
        contentHeight: treeCol.implicitHeight + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: treeCol
            width: tree.width
            spacing: 2

            Repeater {
                model: Diver.data

                delegate: Column {
                    id: cat
                    required property var modelData
                    required property int index
                    width: treeCol.width
                    spacing: 2

                    NodeRow {
                        path: String(cat.index)
                        label: cat.modelData.name
                        depth: 0
                        addLabel: "section"
                    }

                    Repeater {
                        model: cat.modelData.groups || []

                        delegate: Column {
                            id: grp
                            required property var modelData
                            required property int index
                            width: treeCol.width
                            spacing: 2

                            NodeRow {
                                path: cat.index + "-" + grp.index
                                label: grp.modelData.name
                                depth: 1
                                addLabel: "list"
                            }

                            Repeater {
                                model: grp.modelData.subs || []

                                delegate: NodeRow {
                                    required property var modelData
                                    required property int index
                                    path: cat.index + "-" + grp.index + "-" + index
                                    label: modelData.name + "  " + (modelData.dives || []).filter(t => !t.done).length
                                    depth: 2
                                    selectable: true
                                }
                            }

                            NameBox {
                                parentPath: cat.index + "-" + grp.index
                                depth: 2
                            }
                        }
                    }

                    NameBox {
                        parentPath: String(cat.index)
                        depth: 1
                    }
                }
            }

            NameBox {
                parentPath: ""
                depth: 0
            }

            Chip {
                x: 4
                text: "Category"
                glyph: Icons.GLYPHS.plus
                onClicked: root.startNaming("add", "")
            }
        }
    }

    Item {
        anchors.left: tree.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        height: parent.height

        Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: root.list === null
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Make a category, a section and a list on the left,\nthen add tasks to it here."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            lineHeight: 1.3
        }

        Row {
            id: listHead
            visible: root.list !== null
            width: parent.width
            spacing: 8

            Chip {
                text: "Details"
                glyph: Icons.GLYPHS.pencil
                onClicked: root.create("", root.current)
            }
        }

        Flickable {
            anchors.top: listHead.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            width: parent.width
            visible: root.list !== null
            contentHeight: taskCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: taskCol
                width: parent.width
                spacing: 6

                Text {
                    textFormat: Text.PlainText
                    visible: root.list !== null && (root.list.dives || []).length === 0
                    topPadding: 12
                    text: "No tasks here yet."
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Repeater {
                    model: root.list ? root.list.dives || [] : []

                    delegate: DiverTaskRow {
                        required property var modelData
                        width: taskCol.width
                        task: modelData
                        when: modelData.due ? P.dayLabel(modelData.due) + (modelData.time ? " " + modelData.time : "") : ""
                        onOpen: root.edit(modelData.id, root.current)
                        onFocusRequested: root.focusTask(modelData.id)
                    }
                }
            }
        }
    }
}
