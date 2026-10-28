import QtQuick
import qs
import qs.services
import qs.components
import "../../lib/icons.mjs" as Icons
import "../../lib/weather.mjs" as W

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property var d: Weather.data
    readonly property var days: root.d === null ? [] : root.d.days.slice(1, 1 + Math.max(0, Math.floor((root.width - 150) / 64)))
    readonly property string extra: root.d === null ? "" : [root.o.feels !== false ? "Feels " + root.d.feels + "°" : "", root.o.humidity === true ? root.d.humidity + "%" : "", root.o.wind === true ? root.d.wind + " " + root.d.windUnit : ""].filter(s => s !== "").join(" · ")

    Component.onCompleted: {
        if (Weather.fetched === 0 || Date.now() - Weather.fetched > 600000)
            Weather.refresh();
    }

    Text {
        textFormat: Text.PlainText
        visible: root.d === null
        anchors.fill: parent
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: Weather.error !== "" ? Weather.error : !Sky.available ? "Set a location in SylSettings › Desktop › Sky" : "Fetching the forecast…"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Column {
        visible: root.d !== null
        width: Math.min(parent.width, 150)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Row {
            spacing: 8

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.now === null ? "" : Icons.GLYPHS[Weather.now.glyph]
                color: root.frame !== null ? root.frame.accent : Theme.accent
                size: Math.min(44, root.height * 0.32)
            }

            Text {
                textFormat: Text.PlainText
                text: root.d === null ? "" : root.d.temp + "°"
                color: Theme.text
                font.family: Tokens.fontDisplay
                font.pixelSize: Math.min(44, root.height * 0.34)
                font.weight: Font.DemiBold
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: Weather.now === null ? "" : Weather.now.label
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Text {
            textFormat: Text.PlainText
            visible: root.extra !== ""
            width: parent.width
            elide: Text.ElideRight
            text: root.extra
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.days

            delegate: Column {
                required property var modelData
                width: 60
                spacing: 2

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.locale().dayName(new Date(modelData.date + "T12:00").getDay(), Locale.ShortFormat)
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.GLYPHS[W.describe(modelData.code, true).glyph]
                    color: Theme.text
                    size: Tokens.bodySize + 4
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.max + "° " + modelData.min + "°"
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
        }
    }
}
