import QtQuick
import qs
import qs.services
import "../../lib/widgets.mjs" as Wd

Item {
    id: root

    property var frame: null
    readonly property string fontUi: root.frame !== null ? root.frame.fontUi : Tokens.fontUi
    readonly property string fontDisplay: root.frame !== null ? root.frame.fontDisplay : Tokens.fontDisplay
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    property real now: Date.now()
    readonly property var days: Wd.daysUntil(root.o.date, root.now)
    readonly property string title: root.o.title || ""
    readonly property int align: root.o.align === "left" ? Text.AlignLeft : root.o.align === "right" ? Text.AlignRight : Text.AlignHCenter
    readonly property string caption: {
        const n = root.days;
        if (n === null)
            return "";
        const unit = Math.abs(n) === 1 ? "day" : "days";
        if (n === 0)
            return root.title === "" ? "Today" : root.title + " is today";
        if (n > 0)
            return unit + (root.title === "" ? " to go" : " until " + root.title);
        return unit + (root.title === "" ? " ago" : " since " + root.title);
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Text {
        textFormat: Text.PlainText
        visible: root.days === null
        anchors.fill: parent
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: "Set a date like 2026-12-24 in SylSettings › Desktop › Widgets"
        color: Theme.textDim
        font.family: root.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Column {
        visible: root.days !== null
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            textFormat: Text.PlainText
            visible: root.days !== 0
            width: parent.width
            horizontalAlignment: root.align
            text: root.days === null ? "" : String(Math.abs(root.days))
            color: root.frame !== null ? root.frame.accent : Theme.accent
            font.family: root.fontDisplay
            font.pixelSize: Math.min(root.height * 0.5, root.width * 0.4)
            font.weight: Font.DemiBold
            font.features: {
                "tnum": 1
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: root.o.caption !== false || root.days === 0
            width: parent.width
            horizontalAlignment: root.align
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.caption
            color: root.days === 0 ? Theme.text : Theme.textDim
            font.family: root.days === 0 ? root.fontDisplay : root.fontUi
            font.pixelSize: root.days === 0 ? Tokens.titleSize : Tokens.smallSize
            font.weight: root.days === 0 ? Font.DemiBold : Font.Normal
        }
    }
}
