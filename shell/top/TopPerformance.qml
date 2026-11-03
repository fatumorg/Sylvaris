import QtQuick
import qs
import qs.services
import qs.components
import qs.plugins.temp
import "../lib/files.mjs" as F
import "../lib/widgets.mjs" as Wd
import "../lib/temp.mjs" as Tp

Flickable {
    id: page

    required property var task
    readonly property var s: page.task.sample
    readonly property var h: page.task.history
    readonly property real cardW: (page.width - grid.columnSpacing) / 2
    readonly property real cardH: 170
    readonly property var temps: Temps.enabled ? Tp.headline(Temps.sensors) : []

    contentHeight: grid.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: Temps.want("top", true)
    Component.onDestruction: Temps.want("top", false)

    Text {
        textFormat: Text.PlainText
        visible: page.s === null
        text: "Reading /proc…"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
    }

    Grid {
        id: grid
        visible: page.s !== null
        width: page.width
        columns: 2
        columnSpacing: 10
        rowSpacing: 10

        TopGraph {
            width: page.cardW
            height: page.cardH
            title: "Processor"
            value: page.s === null ? "" : Math.round(page.s.cpu.total) + "%"
            sub: page.s === null ? "" : page.s.cpu.cores.length + " threads"
            first: page.h.cpu || []
        }

        Item {
            width: page.cardW
            height: page.cardH

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Text {
                textFormat: Text.PlainText
                x: 12
                y: 10
                text: "Each thread"
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }

            Row {
                id: bars
                x: 12
                y: 40
                width: parent.width - 24
                height: parent.height - 52
                spacing: 3

                Repeater {
                    model: page.s === null ? [] : page.s.cpu.cores

                    delegate: Item {
                        required property real modelData
                        width: (bars.width - bars.spacing * (page.s.cpu.cores.length - 1)) / Math.max(1, page.s.cpu.cores.length)
                        height: bars.height

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.r(3)
                            inner: true
                        }

                        Glass {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(2, parent.height * modelData / 100)
                            radius: Tokens.r(3)
                            inner: true
                            lit: true
                        }
                    }
                }
            }
        }

        TopGraph {
            width: page.cardW
            height: page.cardH
            title: "Memory"
            value: page.s === null ? "" : F.sizeText(page.s.mem.used) + " of " + F.sizeText(page.s.mem.total)
            sub: page.s === null ? "" : page.s.mem.swapTotal > 0 ? "Swap " + F.sizeText(page.s.mem.swapUsed) + " of " + F.sizeText(page.s.mem.swapTotal) : "No swap"
            first: page.h.mem || []
            second: page.h.swap || []
        }

        TopGraph {
            width: page.cardW
            height: page.cardH
            title: "Disks"
            value: page.s === null ? "" : Wd.rateText(page.s.disk.read + page.s.disk.write)
            sub: page.s === null ? "" : "Read " + Wd.rateText(page.s.disk.read) + " · write " + Wd.rateText(page.s.disk.write)
            first: page.h.read || []
            second: page.h.write || []
            max: 0
        }

        TopGraph {
            width: page.cardW
            height: page.cardH
            title: "Network"
            value: page.s === null ? "" : Wd.rateText(page.s.net.rx + page.s.net.tx)
            sub: page.s === null ? "" : "Down " + Wd.rateText(page.s.net.rx) + " · up " + Wd.rateText(page.s.net.tx)
            first: page.h.rx || []
            second: page.h.tx || []
            max: 0
        }

        Repeater {
            model: page.s === null ? [] : page.s.gpus

            delegate: TopGraph {
                required property var modelData
                required property int index
                width: page.cardW
                height: page.cardH
                title: modelData.name
                value: modelData.busy + "%"
                sub: modelData.memTotal > 0 ? "Video memory " + F.sizeText(modelData.memUsed) + " of " + F.sizeText(modelData.memTotal) : ""
                first: page.h.gpus && page.h.gpus[index] ? page.h.gpus[index] : []
            }
        }

        Repeater {
            model: page.temps

            delegate: TopGraph {
                required property var modelData
                width: page.cardW
                height: page.cardH
                title: modelData.device || modelData.label
                value: Math.round(modelData.value) + "°"
                sub: modelData.label
                first: Temps.history[Tp.sensorId(modelData)] || []
                firstTint: Temps.tone(modelData)
                max: Tp.limits(modelData)[1] + 10
            }
        }
    }
}
