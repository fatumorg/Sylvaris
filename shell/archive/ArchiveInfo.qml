import QtQuick
import qs
import qs.services
import qs.components
import qs.files
import "../lib/files.mjs" as F

Item {
    id: info

    required property var archive
    readonly property var counts: info.archive.counts
    readonly property bool ready: info.archive.problem === ""
    readonly property real saved: info.archive.archiveSize > 0 && info.counts.bytes > 0 ? 1 - info.archive.archiveSize / info.counts.bytes : -1
    readonly property var facts: [
        {
            k: "Size",
            v: info.archive.archiveSize >= 0 ? F.sizeText(info.archive.archiveSize) : "…"
        },
        {
            k: "Inside",
            v: !info.ready ? "…" : info.counts.files + (info.counts.files === 1 ? " file" : " files") + (info.counts.folders > 0 ? ", " + info.counts.folders + (info.counts.folders === 1 ? " folder" : " folders") : "")
        },
        {
            k: "Unpacked",
            v: info.ready ? F.sizeText(info.counts.bytes) : "…"
        },
        {
            k: "Saves",
            v: info.saved > 0.005 ? Math.round(info.saved * 100) + "%" : "—"
        }
    ]

    Glass {
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 0
        radius: Tokens.radiusCard
        inner: true
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 0
        contentHeight: col.height + 32
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            x: 16
            y: 18
            width: flick.width - 32
            spacing: 14

            Item {
                width: parent.width
                height: 96

                Glass {
                    anchors.centerIn: parent
                    width: 96
                    height: 96
                    radius: Tokens.r(28)
                    inner: true
                    flowing: false
                    offColor: Theme.tintMid
                }

                Glyph {
                    anchors.centerIn: parent
                    text: info.archive.problem === "locked" ? F.GLYPH.lock : F.GLYPH.archive
                    size: 54
                    color: Theme.accent
                }
            }

            Column {
                width: parent.width
                spacing: 3

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: info.archive.archiveName
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: info.archive.format + (info.archive.canChange ? "" : " · read only")
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: info.facts

                    delegate: Item {
                        id: fact
                        required property var modelData
                        width: parent.width
                        height: 24

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: fact.modelData.k
                            color: Theme.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - 80)
                            horizontalAlignment: Text.AlignRight
                            textFormat: Text.PlainText
                            text: fact.modelData.v
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                            font.features: {
                                "tnum": 1
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                PillButton {
                    width: parent.width
                    label: "Extract everything"
                    glyph: F.GLYPH.extract
                    primary: true
                    enabled: info.ready
                    onClicked: info.archive.act("extractAll")
                }

                PillButton {
                    width: parent.width
                    label: info.archive.selected.length > 0 ? "Extract the selection" : "Extract to…"
                    glyph: F.GLYPH.folderOpen
                    enabled: info.ready
                    onClicked: info.archive.act(info.archive.selected.length > 0 ? "extract" : "extractTo")
                }

                PillButton {
                    width: parent.width
                    label: "Show in SylFiles"
                    glyph: F.GLYPH.folder
                    onClicked: info.archive.act("reveal")
                }
            }

            Text {
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: info.archive.canChange ? "Drop files on the list to add them, Delete takes them out. Drag files out to unpack them anywhere." : "This kind of archive can only be read. Drag files out to unpack them anywhere."
                color: Qt.alpha(Theme.textDim, 0.85)
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }
        }
    }
}
