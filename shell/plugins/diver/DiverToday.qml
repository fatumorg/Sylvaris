import QtQuick
import qs
import qs.services
import qs.components
import "../../lib/diver.mjs" as D
import "../../lib/plan.mjs" as P
import "../../lib/icons.mjs" as Icons
import "../../lib/calendar.mjs" as Cal

Flickable {
    id: root

    readonly property var overdue: D.overdue(Diver.data, Diver.now).filter(x => P.energyOk(x.task, Diver.energy))
    readonly property var todays: Diver.agendaToday.filter(x => P.energyOk(x.task, Diver.energy))
    readonly property var upcoming: {
        const out = [];
        const seen = {};
        for (let i = 1; i <= 7; i++)
            for (const x of Diver.agenda(D.dayKey(Diver.now + i * D.DAY))) {
                if (seen[x.task.id] || Diver.agendaToday.some(y => y.task.id === x.task.id))
                    continue;
                seen[x.task.id] = true;
                if (P.energyOk(x.task, Diver.energy))
                    out.push(x);
            }
        return out;
    }
    readonly property var sections: [
        {
            title: "Overdue",
            items: root.overdue,
            day: true
        },
        {
            title: "Today",
            items: root.todays,
            day: false
        },
        {
            title: "Next 7 days",
            items: root.upcoming,
            day: true
        }
    ]

    signal edit(string id, string where)
    signal focusTask(string id)

    function whenOf(x: var, day: bool): string {
        const time = x.allDay || !x.task.time ? "" : Qt.formatTime(new Date(x.start || D.at(x.task.due, x.task.time)), Cal.timeFormat(Settings.values.clock.format, false));
        const date = day ? P.dayLabel(x.start ? D.dayKey(x.start) : x.task.due) : "";
        return [date, time].filter(Boolean).join(" ");
    }

    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        width: root.width
        spacing: 8

        Item {
            width: col.width
            height: 64

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusRow
                inner: true
            }

            Column {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - energyPick.width - 48
                spacing: 3

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: Diver.next === null ? "Nothing else timed today" : "Next  " + Qt.formatTime(new Date(Diver.next.start), Cal.timeFormat(Settings.values.clock.format, false)) + "  " + D.plain(Diver.next.task.text)
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                    font.weight: Font.Medium
                }

                Text {
                    textFormat: Text.PlainText
                    text: P.doneToday(Diver.data, Diver.now) + " done today"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }

            Segmented {
                id: energyPick
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                current: Diver.energy
                options: [
                    {
                        key: "all",
                        label: "all"
                    },
                    {
                        key: "low",
                        label: "low"
                    },
                    {
                        key: "med",
                        label: "medium"
                    },
                    {
                        key: "high",
                        label: "high"
                    }
                ]
                onPicked: key => Diver.energy = key
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: root.overdue.length === 0 && root.todays.length === 0 && root.upcoming.length === 0
            width: parent.width
            topPadding: 40
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing planned for the next week.\nType above to add something, like “call Ana tomorrow 18:00”."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            lineHeight: 1.3
        }

        Repeater {
            model: root.sections

            delegate: Column {
                id: sec
                required property var modelData
                width: col.width
                spacing: 6
                visible: sec.modelData.items.length > 0

                Item {
                    width: sec.width
                    height: Math.max(heading.implicitHeight, lateButton.visible ? lateButton.implicitHeight : 0)

                    RowButton {
                        id: lateButton
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        visible: sec.modelData.title === "Overdue"
                        icon: Icons.GLYPHS.calendar
                        label: "Move all to today"
                        onClicked: Diver.moveOverdue()
                    }

                    Text {
                        id: heading
                        anchors.bottom: parent.bottom
                        textFormat: Text.PlainText
                        topPadding: 8
                        text: sec.modelData.title + "  " + sec.modelData.items.length
                        color: sec.modelData.title === "Overdue" ? Theme.danger : Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                }

                Repeater {
                    model: sec.modelData.items

                    delegate: DiverTaskRow {
                        required property var modelData
                        width: sec.width
                        task: modelData.task
                        when: root.whenOf(modelData, sec.modelData.day)
                        path: modelData.path.filter(Boolean).join(" › ")
                        showPath: true
                        onOpen: root.edit(modelData.task.id, modelData.ci + "-" + modelData.gi + "-" + modelData.si)
                        onFocusRequested: root.focusTask(modelData.task.id)
                    }
                }
            }
        }
    }
}
