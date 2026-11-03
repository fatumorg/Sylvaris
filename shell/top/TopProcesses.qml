import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/top.mjs" as T
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Item {
    id: page

    required property var task
    property bool pinning: false
    property var cores: []
    readonly property var widths: ({
            pid: 72,
            user: 96,
            cpu: 66,
            mem: 92,
            threads: 72,
            nice: 52,
            state: 100
        })
    readonly property real fixed: T.COLUMNS.filter(c => c.key !== "name").reduce((a, c) => a + page.widths[c.key], 0)
    readonly property var p: page.task.picked
    readonly property bool many: page.task.marked.length > 0
    readonly property var targets: page.many ? page.task.marked : page.p !== null ? [page.p] : []
    readonly property bool stopped: page.targets.length > 0 && page.targets.every(t => t.state === "T")

    function cell(p: var, key: string): string {
        switch (key) {
        case "cpu":
            return p.cpu.toFixed(1) + "%";
        case "mem":
            return p.mem > 0 ? F.sizeText(p.mem) : "";
        case "state":
            return T.STATES[p.state] || p.state;
        default:
            return String(p[key]);
        }
    }

    Connections {
        target: page.task
        function onDetailChanged() {
            if (page.task.detail !== null)
                page.cores = page.task.detail.affinity.slice();
        }
        function onSelectedChanged() {
            page.pinning = false;
        }
    }

    Row {
        id: tools
        width: parent.width
        spacing: 8

        TextBox {
            id: search
            width: Math.min(360, parent.width - treeChip.width - 8)
            placeholder: "Search by name, command, user or PID"
            text: page.task.query
            onTextChanged: page.task.query = text
        }

        Chip {
            id: treeChip
            anchors.verticalCenter: parent.verticalCenter
            text: "Tree"
            glyph: Icons.GLYPHS.tree || ""
            lit: page.task.cfg.tree
            onClicked: Settings.put("top.tree", !page.task.cfg.tree)
        }
    }

    Row {
        id: header
        anchors.top: tools.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 30

        Repeater {
            model: T.COLUMNS

            delegate: Item {
                id: head

                required property var modelData

                width: head.modelData.key === "name" ? header.width - page.fixed : page.widths[head.modelData.key]
                height: header.height

                Text {
                    textFormat: Text.PlainText
                    x: head.modelData.key === "name" ? 12 : 0
                    width: parent.width - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: head.modelData.text ? Text.AlignLeft : Text.AlignRight
                    text: head.modelData.label + (page.task.sortKey === head.modelData.key ? (page.task.desc ? " ↓" : " ↑") : "")
                    elide: Text.ElideRight
                    color: page.task.sortKey === head.modelData.key ? Theme.accent : Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.task.sortBy(head.modelData.key)
                }
            }
        }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.bottom: detail.visible ? detail.top : parent.bottom
        anchors.bottomMargin: detail.visible ? 10 : 0
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: page.task.rows
        reuseItems: true

        delegate: Item {
            id: row

            required property var modelData
            readonly property bool chosen: page.task.selected === row.modelData.pid
            readonly property bool tagged: page.task.tagged.indexOf(row.modelData.pid) >= 0

            width: list.width
            height: 32

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusRow
                inner: true
                lit: row.chosen
                hot: rowArea.containsMouse
                opacity: row.chosen || rowArea.containsMouse ? 1 : 0
            }

            Rectangle {
                visible: row.tagged
                x: 2
                width: 4
                height: parent.height - 12
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: Theme.accent
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || (mouse.modifiers & Qt.ControlModifier))
                        page.task.tag([row.modelData.pid]);
                    else
                        page.task.select(row.modelData.pid);
                }
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: T.COLUMNS

                    delegate: Item {
                        id: c

                        required property var modelData
                        readonly property bool name: c.modelData.key === "name"
                        readonly property real indent: c.name && row.modelData.depth !== undefined ? row.modelData.depth * 16 : 0

                        width: c.name ? header.width - page.fixed : page.widths[c.modelData.key]
                        height: row.height

                        Glyph {
                            x: 8 + c.indent
                            anchors.verticalCenter: parent.verticalCenter
                            visible: c.name && row.modelData.kids > 0
                            text: page.task.folded.indexOf(row.modelData.pid) >= 0 ? Icons.GLYPHS.chevronRight : Icons.GLYPHS.chevronDown
                            size: 14
                            color: Theme.textDim

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.task.fold(row.modelData.pid)
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            x: c.name ? 28 + c.indent : 0
                            width: parent.width - x - 8
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: c.modelData.text ? Text.AlignLeft : Text.AlignRight
                            text: page.cell(row.modelData, c.modelData.key)
                            elide: Text.ElideRight
                            color: row.chosen ? Theme.onAccent : c.name ? Theme.text : Theme.textDim
                            font.family: c.name || c.modelData.key === "user" || c.modelData.key === "state" ? Tokens.fontUi : Tokens.fontMono
                            font.pixelSize: Tokens.smallSize
                        }
                    }
                }
            }
        }
    }

    Item {
        id: detail
        visible: page.targets.length > 0
        anchors.bottom: parent.bottom
        width: parent.width
        height: visible ? box.implicitHeight + 24 : 0

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusCard
            inner: true
        }

        Column {
            id: box
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: page.many ? page.targets.length + " tagged: " + page.targets.map(t => t.name).join(", ") : page.p === null ? "" : page.p.name + " · PID " + page.p.pid + " · " + page.p.user + " · nice " + page.p.nice
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }

            Text {
                textFormat: Text.PlainText
                visible: !page.many
                width: parent.width
                text: page.p === null ? "" : page.p.cmd
                elide: Text.ElideMiddle
                color: Theme.textDim
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.tinySize
            }

            Flow {
                width: parent.width
                spacing: 6

                Chip {
                    text: "End task"
                    glyph: Icons.GLYPHS.close
                    onClicked: page.targets.forEach(t => page.task.signalTo(t.pid, "term"))
                }

                Chip {
                    text: "Kill"
                    glyph: Icons.GLYPHS.stopCircle
                    onClicked: page.targets.forEach(t => page.task.signalTo(t.pid, "kill"))
                }

                Chip {
                    text: page.stopped ? "Resume" : "Pause"
                    glyph: page.stopped ? Icons.GLYPHS.play : Icons.GLYPHS.pause
                    onClicked: {
                        const sig = page.stopped ? "cont" : "stop";
                        page.targets.forEach(t => page.task.signalTo(t.pid, sig));
                    }
                }

                Chip {
                    text: "Lower priority"
                    glyph: Icons.GLYPHS.down
                    onClicked: page.targets.forEach(t => page.task.renice(t.pid, Math.min(19, t.nice + 5)))
                }

                Chip {
                    text: "Raise priority"
                    glyph: Icons.GLYPHS.up
                    onClicked: page.targets.forEach(t => page.task.renice(t.pid, Math.max(-20, t.nice - 5)))
                }

                Chip {
                    text: "Disk: idle only"
                    glyph: Icons.GLYPHS.sleep
                    onClicked: page.targets.forEach(t => page.task.ionice(t.pid, "idle"))
                }

                Chip {
                    text: "Disk: normal"
                    onClicked: page.targets.forEach(t => page.task.ionice(t.pid, "best-effort"))
                }

                Chip {
                    visible: !page.many
                    text: "Processors…"
                    glyph: Icons.GLYPHS.memory
                    lit: page.pinning
                    onClicked: {
                        page.pinning = !page.pinning;
                        if (page.pinning)
                            page.task.inspect(page.p.pid);
                    }
                }

                Chip {
                    visible: !page.many
                    text: "Open files"
                    glyph: Icons.GLYPHS.folder
                    lit: page.task.files !== null
                    onClicked: page.task.openFiles(page.p.pid)
                }

                Chip {
                    visible: page.many
                    text: "Clear tags"
                    onClicked: page.task.tag([])
                }
            }

            Flow {
                visible: !page.many && page.pinning && page.task.detail !== null
                width: parent.width
                spacing: 6

                Repeater {
                    model: page.task.detail === null ? 0 : page.task.detail.cores

                    delegate: Chip {
                        required property int index
                        text: "CPU " + index
                        lit: page.cores.indexOf(index) >= 0
                        onClicked: page.cores = lit ? page.cores.filter(c => c !== index) : page.cores.concat([index]).sort((a, b) => a - b)
                    }
                }

                Chip {
                    text: "Apply"
                    glyph: Icons.GLYPHS.check
                    enabled: page.cores.length > 0
                    onClicked: {
                        page.task.pin(page.p.pid, page.cores);
                        page.pinning = false;
                    }
                }
            }

            ListView {
                visible: !page.many && page.task.files !== null
                width: parent.width
                height: Math.min(140, contentHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: page.task.files === null ? [] : page.task.files

                delegate: Text {
                    required property var modelData
                    textFormat: Text.PlainText
                    width: ListView.view.width
                    text: modelData.fd + "  " + modelData.target
                    elide: Text.ElideMiddle
                    color: Theme.textDim
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.tinySize
                }
            }

            Text {
                textFormat: Text.PlainText
                visible: !page.many && page.task.files !== null && page.task.files.length === 0
                text: "No open files you can see; processes of other users hide theirs"
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }
        }
    }
}
