import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F

Item {
    id: details

    required property var files
    readonly property var entry: details.files.focusEntry
    readonly property int many: details.files.selected.length
    readonly property string full: details.entry !== null ? F.joinPath(details.files.path, details.entry.name) : details.files.path
    readonly property var info: details.files.info
    readonly property var rows: {
        if (details.many > 1) {
            const picked = details.files.items.filter(e => details.files.selection[e.name] === true);
            const bytes = picked.filter(e => !e.dir).reduce((sum, e) => sum + e.size, 0);
            return [
                {
                    k: "Folders",
                    v: String(picked.filter(e => e.dir).length)
                },
                {
                    k: "Files",
                    v: String(picked.filter(e => !e.dir).length)
                },
                {
                    k: "Size of files",
                    v: F.sizeText(bytes)
                }
            ];
        }
        const e = details.entry;
        const isDir = e === null || e.dir;
        return [
            {
                k: "Kind",
                v: e === null ? "Folder" : F.kindLabel(e.name, e.dir)
            },
            {
                k: isDir ? "Contains" : "Size",
                v: isDir ? (details.info.count >= 0 ? F.countText(details.info.count) + (details.info.bytes >= 0 ? " · " + F.sizeText(details.info.bytes) : "") : "…") : F.sizeText(e.size)
            },
            {
                k: "Modified",
                v: e === null ? "" : F.whenText(e.modified, Date.now())
            },
            {
                k: "Where",
                v: F.pretty(e === null ? F.parentOf(details.files.path) : details.files.path, details.files.home)
            },
            {
                k: "Access",
                v: details.info.perm === "" ? "…" : details.info.perm + " · " + details.info.owner
            }
        ].filter(r => r.v !== "");
    }

    Glass {
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 0
        radius: Tokens.radiusCard
        inner: true
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 0
        contentHeight: col.height + 32
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            x: 18
            y: 18
            width: parent.width - 36
            spacing: 14

            Item {
                width: parent.width
                height: 168

                FileIcon {
                    anchors.centerIn: parent
                    files: details.files
                    folder: details.entry !== null ? details.files.path : F.parentOf(details.files.path)
                    entry: details.many > 1 ? null : details.entry !== null ? details.entry : {
                        name: F.nameOf(details.files.path),
                        dir: true,
                        size: 0,
                        modified: 0
                    }
                    size: 140
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: details.many > 1 ? details.many + " items selected" : details.entry !== null ? details.entry.name : details.files.path === details.files.home ? "Home" : F.nameOf(details.files.path)
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: details.rows

                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 2

                        Text {
                            textFormat: Text.PlainText
                            text: modelData.k
                            color: Theme.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.tinySize
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.6
                        }

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: modelData.v
                            wrapMode: Text.WrapAnywhere
                            color: Theme.text
                            font.family: modelData.k === "Access" ? Tokens.fontMono : Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                        }
                    }
                }
            }
        }
    }
}
