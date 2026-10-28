import QtQuick
import qs
import qs.services
import qs.components
import "../lib/sections.mjs" as Sec
import "../lib/settingsIndex.mjs" as X

Column {
    id: root

    property string query: ""
    property int current: 0
    readonly property var results: X.searchSettings(root.query, Settings.shown.plugins.enabled).slice(0, 8)

    signal picked(var entry)

    function accept(): void {
        if (root.results.length > 0)
            root.picked(root.results[Math.min(root.current, root.results.length - 1)]);
    }

    function step(d: int): void {
        if (root.results.length > 0)
            root.current = (root.current + d + root.results.length) % root.results.length;
    }

    function place(tab: string): string {
        const where = Sec.resolveSection(tab);
        const hub = where === null ? null : Sec.HUBS.find(h => h.key === where.hub);
        const sec = Sec.SECTIONS.find(s => s.key === tab);
        return (hub ? hub.label + "  ›  " : "") + (sec ? sec.label : tab);
    }

    spacing: 6
    onQueryChanged: root.current = 0

    Text {
        textFormat: Text.PlainText
        width: root.width
        visible: root.results.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing matches “" + root.query.trim() + "”"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
    }

    Repeater {
        model: root.results

        delegate: Item {
            id: hit

            required property var modelData
            required property int index
            readonly property var value: Settings.get(hit.modelData.key)
            readonly property bool flag: typeof hit.value === "boolean"

            width: root.width
            height: 60

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusRow
                hot: area.containsMouse
                lit: hit.index === root.current
                raised: hit.index === root.current
            }

            Column {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - (hit.flag ? 70 : 0)
                spacing: 2

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    elide: Text.ElideRight
                    text: hit.modelData.title
                    color: hit.index === root.current ? Theme.onAccent : Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.place(hit.modelData.tab)
                    color: hit.index === root.current ? Theme.onAccent : Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.current = hit.index
                onClicked: root.picked(hit.modelData)
            }

            Toggle {
                visible: hit.flag
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                checked: hit.modelData.invert ? hit.value !== true : hit.value === true
                onToggled: v => Settings.put(hit.modelData.key, hit.modelData.invert ? !v : v)
            }
        }
    }
}
