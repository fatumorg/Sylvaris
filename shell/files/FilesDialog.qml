import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FocusScope {
    id: dialog

    required property var files
    readonly property string kind: dialog.files.dialog
    readonly property bool open: dialog.kind !== ""
    readonly property bool choosing: dialog.kind === "openWith"
    readonly property int count: dialog.files.targets.length
    readonly property string what: dialog.count === 1 ? "“" + F.nameOf(dialog.files.targets[0]) + "”" : dialog.count + " items"
    property string query: ""
    property int lit: 0
    readonly property var apps: dialog.choosing ? F.openers(DesktopEntries.applications.values.map(e => ({
                id: e.id,
                name: e.name,
                icon: e.icon,
                categories: e.categories,
                execString: e.execString
            })), F.kindOf(F.nameOf(dialog.files.targets[0] || ""), false), dialog.query) : []

    visible: card.opacity > 0
    onOpenChanged: {
        if (dialog.open) {
            dialog.query = "";
            dialog.lit = 0;
            showAnim.restart();
            if (dialog.choosing)
                Qt.callLater(() => search.forceActiveFocus());
            else
                dialog.forceActiveFocus();
        } else {
            showAnim.stop();
            card.opacity = 0;
        }
    }
    onQueryChanged: dialog.lit = 0

    function cancel(): void {
        dialog.files.dialog = "";
        dialog.files.focusView();
    }

    function launch(i: int): void {
        if (i >= 0 && i < dialog.apps.length)
            dialog.files.openWith(dialog.apps[i]);
        dialog.files.focusView();
    }

    Keys.onEscapePressed: dialog.cancel()
    Keys.onReturnPressed: dialog.choosing ? dialog.launch(dialog.lit) : dialog.files.confirm()
    Keys.onEnterPressed: dialog.choosing ? dialog.launch(dialog.lit) : dialog.files.confirm()

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.base, 0.45)
        opacity: card.opacity
    }

    MouseArea {
        anchors.fill: parent
        enabled: dialog.open
        acceptedButtons: Qt.AllButtons
        onClicked: dialog.cancel()
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, dialog.choosing ? 420 : 400)
        height: body.height + 44
        opacity: 0
        scale: 0.96 + 0.04 * card.opacity

        NumberAnimation {
            id: showAnim
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusPanel
            raised: true
            offColor: Theme.surface
            offBorder: Theme.line
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: body
            x: 24
            y: 22
            width: parent.width - 48
            spacing: 14

            Row {
                spacing: 12

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dialog.choosing ? F.GLYPH.openWith : dialog.kind === "trash" ? F.GLYPH.trash : dialog.kind === "remove" ? F.GLYPH.archive : F.GLYPH.deleteForever
                    size: 24
                    color: dialog.choosing || dialog.kind === "trash" ? Theme.accent : Theme.danger
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: ({
                            delete: "Delete permanently?",
                            remove: "Remove from the archive?",
                            replace: "Replace " + dialog.what + "?",
                            trash: "Move to the trash?",
                            empty: "Empty the trash?",
                            openWith: "Open " + dialog.what + " with"
                        })[dialog.kind] || ""
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.titleSize
                    font.weight: Font.DemiBold
                }
            }

            Text {
                visible: !dialog.choosing
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: dialog.kind === "delete" ? dialog.what + " will be gone for good. This cannot be undone." : dialog.kind === "remove" ? dialog.what + " will be taken out of the archive for good." : dialog.kind === "replace" ? "Something with that name is already in this folder. Saving overwrites it." : dialog.kind === "trash" ? dialog.what + " will go to the trash. You can restore or undo it." : "Everything in the trash will be deleted for good."
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Item {
                visible: dialog.choosing
                width: parent.width
                height: 38

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    inner: true
                    offColor: Theme.tintSoft
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.accent
                    visible: search.activeFocus
                }

                Glyph {
                    id: lens
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.GLYPHS.search
                    size: 15
                    color: Theme.textDim
                }

                TextInput {
                    id: search
                    anchors.left: lens.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    onTextEdited: dialog.query = search.text
                    Keys.onUpPressed: dialog.lit = Math.max(0, dialog.lit - 1)
                    Keys.onDownPressed: dialog.lit = Math.min(dialog.apps.length - 1, dialog.lit + 1)
                    Keys.onReturnPressed: dialog.launch(dialog.lit)
                    Keys.onEnterPressed: dialog.launch(dialog.lit)
                    Keys.onEscapePressed: dialog.cancel()

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        textFormat: Text.PlainText
                        text: "Find an app"
                        color: Theme.textDim
                        font: search.font
                    }
                }
            }

            ListView {
                id: appList
                visible: dialog.choosing
                width: parent.width
                height: Math.min(8, Math.max(1, dialog.apps.length)) * 40
                clip: true
                model: dialog.apps
                currentIndex: dialog.lit
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)

                delegate: Item {
                    id: app
                    required property var modelData
                    required property int index
                    readonly property bool on: dialog.lit === app.index
                    readonly property string icon: Stack.iconPath(app.modelData.icon || "", true)
                    width: appList.width
                    height: 40

                    Glass {
                        anchors.fill: parent
                        radius: 12
                        inner: true
                        flowing: false
                        hot: appArea.containsMouse
                        lit: app.on
                        opacity: app.on || appArea.containsMouse ? 1 : 0
                        offColor: Theme.tintMid
                    }

                    Image {
                        id: appIcon
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        visible: app.icon !== ""
                        source: app.icon
                        sourceSize.width: 48
                        sourceSize.height: 48
                        asynchronous: true
                    }

                    Glyph {
                        x: 10
                        width: 24
                        anchors.verticalCenter: parent.verticalCenter
                        visible: app.icon === ""
                        text: Icons.GLYPHS.apps
                        size: 18
                        color: app.on ? Theme.onAccent : Theme.accent
                    }

                    Text {
                        x: 46
                        width: parent.width - 56
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: app.modelData.name
                        elide: Text.ElideRight
                        color: app.on ? Theme.onAccent : Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }

                    MouseArea {
                        id: appArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: dialog.lit = app.index
                        onClicked: dialog.launch(app.index)
                    }
                }
            }

            Text {
                visible: dialog.choosing && dialog.apps.length === 0
                textFormat: Text.PlainText
                text: "No app matches “" + dialog.query + "”"
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                visible: !dialog.choosing
                anchors.right: parent.right
                spacing: 8

                PillButton {
                    label: "Cancel"
                    onClicked: dialog.cancel()
                }

                PillButton {
                    label: ({
                            delete: "Delete",
                            remove: "Remove",
                            replace: "Replace",
                            trash: "Move to the trash",
                            empty: "Empty trash"
                        })[dialog.kind] || ""
                    danger: dialog.kind !== "trash"
                    primary: dialog.kind === "trash"
                    onClicked: dialog.files.confirm()
                }
            }
        }
    }
}
