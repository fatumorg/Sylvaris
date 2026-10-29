import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

PopupWindow {
    id: menu

    property var item: null
    property var stack: []
    property real phase: 0
    readonly property var handle: menu.stack.length > 0 ? menu.stack[menu.stack.length - 1] : menu.item !== null && menu.item.hasMenu ? menu.item.menu : null
    readonly property string heading: menu.item === null ? "" : menu.item.tooltipTitle || menu.item.title || menu.item.id

    signal done

    function show(trayItem: var, source: var): void {
        menu.item = trayItem;
        menu.stack = [];
        const p = source.mapToItem(null, 0, source.height + 6);
        menu.anchor.rect.x = p.x;
        menu.anchor.rect.y = p.y;
        menu.visible = true;
    }

    function finish(): void {
        menu.visible = false;
        menu.done();
    }

    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.FlipY
    implicitWidth: Tokens.deckMenuWidth
    implicitHeight: body.implicitHeight + 16
    color: "transparent"
    grabFocus: true
    onVisibleChanged: {
        if (visible) {
            menu.phase = 0;
            menuIn.restart();
            body.forceActiveFocus();
        } else {
            menu.stack = [];
        }
    }

    NumberAnimation {
        id: menuIn
        target: menu
        property: "phase"
        to: 1
        duration: Tokens.enterDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    QsMenuOpener {
        id: opener
        menu: menu.handle
    }

    Glass {
        anchors.fill: parent
        radius: Tokens.radiusCard
        raised: true
        offColor: Theme.surface
        offBorder: Theme.line
        opacity: menu.phase
        scale: 0.92 + 0.08 * menu.phase
        transformOrigin: Item.Top
    }

    component MenuRow: Item {
        id: row

        property string glyph: ""
        property string icon: ""
        property string text: ""
        property bool trailing: false
        property bool checked: false
        property bool checkable: false
        readonly property bool lit: rowArea.containsMouse || row.activeFocus

        signal picked

        width: body.width
        height: 34
        opacity: row.enabled ? 1 : 0.4
        activeFocusOnTab: row.enabled
        Keys.onReturnPressed: row.picked()
        Keys.onEnterPressed: row.picked()
        Keys.onSpacePressed: row.picked()

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusRow - 4
            inner: true
            opacity: row.lit && row.enabled ? 1 : 0
            offBorder: row.activeFocus ? Theme.accent : "transparent"
            scale: rowArea.pressed ? 0.97 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }

        IconImage {
            visible: row.icon !== "" && row.glyph === ""
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            source: row.icon
        }

        Glyph {
            visible: row.glyph !== ""
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.glyph
            size: 15
            color: Theme.accent
        }

        Text {
            textFormat: Text.PlainText
            x: row.glyph !== "" || row.icon !== "" ? 38 : 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (row.trailing || row.checkable ? 34 : 12)
            text: row.text
            elide: Text.ElideRight
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Glyph {
            visible: row.trailing || row.checkable && row.checked
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.trailing ? Icons.GLYPHS.chevronRight : Icons.GLYPHS.check
            size: 13
            color: row.trailing ? Theme.textDim : Theme.accent
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            enabled: row.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }

    Column {
        id: body
        x: 8
        y: 8
        width: parent.width - 16
        opacity: menu.phase
        scale: 0.92 + 0.08 * menu.phase
        transformOrigin: Item.Top
        focus: true
        Keys.onEscapePressed: {
            if (menu.stack.length > 0)
                menu.stack = menu.stack.slice(0, -1);
            else
                menu.finish();
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            height: 30
            leftPadding: 12
            rightPadding: 12
            verticalAlignment: Text.AlignVCenter
            text: menu.heading.toUpperCase()
            elide: Text.ElideRight
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
            font.weight: Font.DemiBold
        }

        MenuRow {
            visible: menu.stack.length > 0
            glyph: Icons.GLYPHS.chevronLeft
            text: "Back"
            onPicked: menu.stack = menu.stack.slice(0, -1)
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: entry
                required property var modelData
                width: body.width
                height: entry.modelData.isSeparator ? 9 : 34

                Divider {
                    visible: entry.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 16
                }

                MenuRow {
                    visible: !entry.modelData.isSeparator
                    enabled: entry.modelData.enabled
                    icon: entry.modelData.icon
                    text: entry.modelData.text.replace(/_(?!_)/g, "").replace(/__/g, "_")
                    trailing: entry.modelData.hasChildren
                    checkable: entry.modelData.buttonType !== QsMenuButtonType.None
                    checked: entry.modelData.checkState === Qt.Checked
                    onPicked: {
                        if (entry.modelData.hasChildren) {
                            menu.stack = menu.stack.concat([entry.modelData]);
                            return;
                        }
                        entry.modelData.triggered();
                        menu.finish();
                    }
                }
            }
        }

        Divider {
            visible: opener.children.values.length > 0 && menu.stack.length === 0
            x: 8
            width: parent.width - 16
        }

        MenuRow {
            visible: menu.stack.length === 0 && menu.item !== null && !menu.item.onlyMenu
            glyph: Icons.GLYPHS.open
            text: "Open"
            onPicked: {
                menu.item.activate();
                menu.finish();
            }
        }

        MenuRow {
            visible: menu.stack.length === 0 && menu.item !== null && !menu.item.onlyMenu
            glyph: Icons.GLYPHS.starFour
            text: "Secondary action"
            onPicked: {
                menu.item.secondaryActivate();
                menu.finish();
            }
        }
    }
}
