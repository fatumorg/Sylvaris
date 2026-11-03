import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/widgets.mjs" as Wd
import "../lib/icons.mjs" as Icons

PanelWindow {
    id: flow

    required property var host
    readonly property var at: Object.assign({
            screen: "",
            x: 0,
            y: 0
        }, flow.host.picking)
    readonly property var types: Object.keys(Wd.TYPES).filter(t => t !== "stack" && (Wd.TYPES[t].plugin === undefined || Settings.values.plugins.enabled[Wd.TYPES[t].plugin] === true))
    property string type: ""
    property var options: ({})
    readonly property var item: flow.type === "" ? null : {
        id: "preview",
        type: flow.type,
        w: Wd.TYPES[flow.type].size[0],
        h: Wd.TYPES[flow.type].size[1],
        options: Wd.validateOptions(flow.type, flow.options)
    }
    readonly property real previewW: flow.item === null ? 0 : Wd.span(flow.item.w, flow.host.cfg.cell, flow.host.cfg.gap)
    readonly property real previewH: flow.item === null ? 0 : Wd.span(flow.item.h, flow.host.cfg.cell, flow.host.cfg.gap)

    function choose(type: string): void {
        flow.options = {};
        flow.type = type;
    }

    function finish(): void {
        flow.host.add(flow.type, Object.assign({}, flow.at, {
            options: flow.options
        }));
        flow.host.picking = null;
    }

    screen: Stack.screens.find(s => s.name === flow.at.screen) || null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Qt.rgba(0, 0, 0, 0.22)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sylwidget-add"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        onClicked: flow.host.picking = null
    }

    Item {
        id: card

        readonly property real pad: 18
        width: 560
        height: Math.min(flow.height - 48, body.implicitHeight + card.pad * 2)
        x: Math.max(24, Math.min(flow.width - card.width - 24, flow.at.x - card.width / 2))
        y: Math.max(24, Math.min(flow.height - card.height - 24, flow.at.y - 24))
        focus: true
        Keys.onEscapePressed: flow.host.picking = null
        Keys.onReturnPressed: {
            if (flow.type !== "")
                flow.finish();
        }

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusCard
        }

        MouseArea {
            anchors.fill: parent
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: card.pad
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS[flow.type === "" ? "plus" : Wd.TYPES[flow.type].glyph] || ""
                        size: 22
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32 - (back.visible ? back.width + 10 : 0)
                        textFormat: Text.PlainText
                        text: flow.type === "" ? "Add a widget here" : Wd.TYPES[flow.type].label
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Tokens.fontDisplay
                        font.pixelSize: Tokens.titleSize
                        font.weight: Tokens.titleWeight
                    }

                    Chip {
                        id: back
                        anchors.verticalCenter: parent.verticalCenter
                        visible: flow.type !== ""
                        text: "Back"
                        onClicked: flow.type = ""
                    }
                }

                Flow {
                    visible: flow.type === ""
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: flow.types

                        delegate: Chip {
                            required property string modelData
                            text: Wd.TYPES[modelData].label
                            glyph: Icons.GLYPHS[Wd.TYPES[modelData].glyph] || ""
                            onClicked: flow.choose(modelData)
                        }
                    }
                }

                Item {
                    visible: flow.item !== null
                    width: parent.width
                    height: Math.min(220, flow.previewH)

                    WidgetFrame {
                        readonly property real fit: Math.min(1, parent.width / Math.max(1, flow.previewW), parent.height / Math.max(1, flow.previewH))
                        anchors.centerIn: parent
                        width: flow.previewW
                        height: flow.previewH
                        scale: fit
                        item: flow.item
                        cfg: flow.host.cfg
                        host: flow.host
                        screenName: flow.at.screen
                    }
                }

                OptionFields {
                    visible: flow.type !== ""
                    width: parent.width
                    type: flow.type
                    values: flow.item === null ? ({}) : flow.item.options
                    onEdited: (key, value) => {
                        const next = Object.assign({}, flow.options);
                        next[key] = value;
                        flow.options = next;
                    }
                }

                Row {
                    visible: flow.type !== ""
                    anchors.right: parent.right
                    spacing: 8

                    Chip {
                        text: "Cancel"
                        onClicked: flow.host.picking = null
                    }

                    Chip {
                        text: "Add here"
                        glyph: Icons.GLYPHS.plus || ""
                        onClicked: flow.finish()
                    }
                }
            }
        }
    }
}
