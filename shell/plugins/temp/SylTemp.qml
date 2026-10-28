import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/temp.mjs" as T
import "../../lib/icons.mjs" as Icons

Popup {
    id: root

    readonly property var groups: T.devices(Temps.sensors)

    namespace: "syltemp"
    corner: root.local.placement.temp
    panelWidth: Tokens.tempWidth
    panelHeight: Tokens.tempHeight

    function state(): var {
        return Object.assign({
            open: root.shown
        }, Temps.state());
    }

    onLiveChanged: Temps.want("panel", root.live)
    Component.onDestruction: Temps.want("panel", false)

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: parent.width
            spacing: 14

            Row {
                width: parent.width
                spacing: 14

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.GLYPHS.thermometer
                    size: 26
                    color: Temps.tone(Temps.top)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40

                    Text {
                        textFormat: Text.PlainText
                        text: "SylTemp"
                        color: Theme.text
                        font.family: Tokens.fontDisplay
                        font.pixelSize: Tokens.titleSize + 3
                        font.weight: Tokens.titleWeight
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: Temps.sensors.length === 0 ? (Temps.checked ? "Waiting for TempInfoCLI" : "Starting") : T.compact(Temps.sensors) + (Temps.legacy ? " · every 5 s" : " · live")
                        elide: Text.ElideRight
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                visible: Temps.error !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: Temps.error
                color: Temps.available ? Theme.textDim : Theme.danger
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Repeater {
                model: root.groups

                delegate: Item {
                    id: card

                    required property var modelData
                    readonly property var lead: T.headline(card.modelData.sensors)[0] || T.hottest(card.modelData.sensors) || card.modelData.sensors[0]
                    readonly property string leadId: T.sensorId(card.lead)
                    readonly property var trail: Temps.history[card.leadId] || []

                    width: body.width
                    height: inner.implicitHeight + 28

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusRow
                        inner: true
                        offColor: Theme.tintMid
                    }

                    Column {
                        id: inner
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 12

                            Digits {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(card.lead.value) + (card.lead.unit === "°C" ? "°" : "")
                                color: Temps.tone(card.lead)
                                font.family: Tokens.fontDisplay
                                font.pixelSize: 34
                                font.weight: Font.DemiBold
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 110

                                Text {
                                    textFormat: Text.PlainText
                                    width: parent.width
                                    text: card.modelData.name
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.bodySize
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    width: parent.width
                                    text: card.lead.label + (Temps.peaks[card.leadId] === undefined ? "" : " · peak " + Math.round(Temps.peaks[card.leadId]) + (card.lead.unit === "°C" ? "°" : ""))
                                    elide: Text.ElideRight
                                    color: Theme.textDim
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.smallSize
                                }
                            }
                        }

                        Rectangle {
                            visible: T.level(card.lead) !== "none"
                            width: parent.width
                            height: 6
                            radius: height / 2
                            color: Qt.alpha(Theme.text, 0.1)

                            Rectangle {
                                width: parent.width * T.headroom(card.lead)
                                height: parent.height
                                radius: height / 2
                                color: Temps.tone(card.lead)
                            }
                        }

                        Canvas {
                            id: spark
                            visible: card.trail.length > 1
                            width: parent.width
                            height: 34
                            onPaint: {
                                const ctx = getContext("2d");
                                const t = card.trail;
                                ctx.reset();
                                if (t.length < 2)
                                    return;
                                const lo = Math.min.apply(null, t) - 1;
                                const hi = Math.max.apply(null, t) + 1;
                                ctx.strokeStyle = Temps.tone(card.lead);
                                ctx.lineWidth = 1.5;
                                ctx.beginPath();
                                for (let i = 0; i < t.length; i++) {
                                    const x = i / (t.length - 1) * width;
                                    const y = height - (t[i] - lo) / (hi - lo) * height;
                                    if (i === 0)
                                        ctx.moveTo(x, y);
                                    else
                                        ctx.lineTo(x, y);
                                }
                                ctx.stroke();
                            }

                            Connections {
                                target: card
                                function onTrailChanged(): void {
                                    if (spark.visible)
                                        spark.requestPaint();
                                }
                            }
                        }

                        Repeater {
                            model: card.modelData.sensors

                            delegate: Item {
                                id: line

                                required property var modelData
                                readonly property string sid: T.sensorId(line.modelData)
                                readonly property bool pinned: Temps.cfg.pinned.indexOf(line.sid) >= 0

                                width: inner.width
                                height: 28

                                Text {
                                    textFormat: Text.PlainText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 130
                                    text: line.modelData.label
                                    elide: Text.ElideRight
                                    color: Theme.textSoft
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.smallSize
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: pinChip.left
                                    anchors.rightMargin: 10
                                    text: (line.modelData.unit === "°C" ? Math.round(line.modelData.value) + "°" : Math.round(line.modelData.value) + " " + line.modelData.unit)
                                    color: Temps.tone(line.modelData)
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.smallSize
                                    font.weight: Font.DemiBold
                                }

                                Chip {
                                    id: pinChip
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: Icons.GLYPHS.pin
                                    text: line.pinned ? "Pinned" : "Pin"
                                    lit: line.pinned
                                    onClicked: Temps.pin(line.sid)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
