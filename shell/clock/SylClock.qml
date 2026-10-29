import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.plugins.diver
import qs.components
import "../lib/calendar.mjs" as C
import "../lib/sky.mjs" as K
import "../lib/icons.mjs" as Icons
import "../lib/weather.mjs" as Wx
import "../lib/motion.mjs" as M

Popup {
    id: root

    readonly property int dayMs: 86400000
    property date now: new Date()
    property int year: root.now.getFullYear()
    property int month: root.now.getMonth()
    readonly property int firstDay: Qt.locale().firstDayOfWeek
    readonly property var cells: C.monthGrid(root.year, root.month, root.firstDay)
    readonly property var labels: C.weekdayLabels(root.firstDay, [0, 1, 2, 3, 4, 5, 6].map(d => Qt.locale().dayName(d, Locale.NarrowFormat)))
    readonly property real sunAlt: Sky.sun.altitude
    readonly property real light: Math.max(0, Math.min(1, (root.sunAlt + 10) / 22))
    readonly property real dark: Math.max(0, Math.min(1, (-root.sunAlt - 2) / 14))
    readonly property real glow: Math.exp(-Math.pow(root.sunAlt / 7, 2))
    property string picked: ""
    readonly property var busy: Diver.busy(root.year, root.month)

    namespace: "sylclock"
    corner: root.local.clock.corner
    panelWidth: Tokens.clockWidth
    panelHeight: Tokens.clockHeight + (Weather.enabled ? Tokens.clockWeatherHeight + Tokens.gap : 0)

    onOpened: {
        root.picked = "";
        Diver.sync();
        root.now = new Date();
        root.year = root.now.getFullYear();
        root.month = root.now.getMonth();
        Sky.tick();
        if (Weather.fetched === 0 || Date.now() - Weather.fetched > 600000)
            Weather.refresh();
    }

    function hhmm(t: real): string {
        return t ? Qt.formatTime(new Date(t), "HH:mm") : "—";
    }

    function span(ms: real): string {
        const m = Math.round(ms / 60000);
        return Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m";
    }

    function peak(curve: var): real {
        let p = -90;
        for (const s of curve)
            p = Math.max(p, s.altitude);
        return p;
    }

    function daylightText(): string {
        const t = Sky.sunTimes;
        if (t.rise && t.set && t.set > t.rise)
            return root.span(t.set - t.rise);
        if (t.rise || t.set)
            return root.span(t.set ? t.set - Sky.day : Sky.day + root.dayMs - t.rise);
        return root.peak(Sky.sunCurve) > K.SUN_HORIZON ? "Polar day" : "Polar night";
    }

    function relativeDay(t: real): string {
        const d = Math.round((K.dayStart(t) - Sky.day) / root.dayMs);
        if (d <= 0)
            return "today";
        if (d === 1)
            return "tomorrow";
        return "in " + d + " days";
    }

    function moonNext(): string {
        const full = Sky.phaseName === "Full moon";
        const t = full ? Sky.nextNew : Sky.nextFull;
        if (!t)
            return "";
        return (full ? "New moon " : "Full moon ") + root.relativeDay(t) + " · " + Qt.formatDate(new Date(t), "ddd d MMM");
    }

    function place(): string {
        if (Sky.source === "timezone")
            return Sky.zone.split("/").pop().replace(/_/g, " ");
        if (Sky.source === "config")
            return Math.abs(Sky.latitude).toFixed(1) + "°" + (Sky.latitude < 0 ? "S" : "N") + "  " + Math.abs(Sky.longitude).toFixed(1) + "°" + (Sky.longitude < 0 ? "W" : "E");
        return "";
    }

    function keyOf(cell: var): string {
        return cell.year + "-" + String(cell.month + 1).padStart(2, "0") + "-" + String(cell.day).padStart(2, "0");
    }

    function shift(delta: int): void {
        const m = C.shiftMonth(root.year, root.month, delta);
        root.year = m.year;
        root.month = m.month;
    }

    Timer {
        interval: 1000
        running: root.shown
        repeat: true
        onTriggered: root.now = new Date()
    }

    Item {
        id: leftColumn
        x: Tokens.panelPaddingX
        y: 22 + 14 * (1 - M.stagger(root.phase, 0, 3, Tokens.staggerSpread))
        width: Tokens.clockSkyWidth
        height: Tokens.clockHeight - 44
        opacity: M.stagger(root.phase, 0, 3, Tokens.staggerSpread)

        Row {
            id: timeRow
            spacing: 6

            Text {
                textFormat: Text.PlainText
                text: Qt.formatTime(root.now, "HH:mm")
                color: Theme.text
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.clockSize
                font.weight: Font.DemiBold
                font.letterSpacing: -1
            }

            Text {
                textFormat: Text.PlainText
                anchors.baseline: parent.children[0].baseline
                text: Qt.formatTime(root.now, "ss")
                color: Theme.textDim
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.titleSize
            }
        }

        Text {
            textFormat: Text.PlainText
            id: dateText
            anchors.top: timeRow.bottom
            text: Qt.formatDate(root.now, "dddd, d MMMM") + (root.place() !== "" ? "  ·  " + root.place() : "")
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.dateSize
        }

        Item {
            id: sky
            y: 104
            width: parent.width
            height: Tokens.clockSkyHeight

            readonly property real h0: height * 0.62
            readonly property real maxUp: Math.max(20, root.peak(Sky.sunCurve), root.peak(Sky.moonCurve)) + 8

            function xOf(t: real): real {
                return (t - Sky.day) / root.dayMs * width;
            }

            function yOf(a: real): real {
                return a >= 0 ? h0 - a / maxUp * (h0 - 16) : h0 + (-a) / 90 * (height - h0 - 22);
            }

            function points(curve: var, past: bool): var {
                const out = [];
                const t = Sky.now;
                for (const s of curve) {
                    if ((s.t <= t) === past)
                        out.push(Qt.point(xOf(s.t), yOf(s.altitude)));
                }
                return out;
            }

            function joined(curve: var, past: bool, body: var): var {
                const pts = points(curve, past);
                const p = Qt.point(xOf(Sky.now), yOf(body.altitude));
                return past ? pts.concat([p]) : [p].concat(pts);
            }

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
                offBorder: Theme.cardLine
            }

            RoundClip {
                anchors.fill: parent
                radius: Tokens.radiusCard

                Rectangle {
                    width: sky.width
                    height: sky.h0
                    opacity: 0.9
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.lighter(Qt.tint(Theme.base, Qt.alpha(Theme.accentDeep, 0.12 + 0.4 * root.light)), 1 + 0.35 * root.light)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.tint(Qt.tint(Theme.base, Qt.alpha(Theme.accentHi, 0.1 + 0.3 * root.light)), Qt.alpha("#ff9a57", 0.5 * root.glow))
                        }
                    }
                }

                Repeater {
                    model: 42
                    delegate: Rectangle {
                        required property int index
                        readonly property real seed: Math.abs(Math.sin(index * 127.1 + 311.7) * 43758.5453) % 1
                        readonly property real seed2: Math.abs(Math.sin(index * 269.5 + 183.3) * 43758.5453) % 1
                        x: seed * sky.width
                        y: seed2 * (sky.h0 - 20) + 4
                        width: seed > 0.85 ? 2.2 : 1.4
                        height: width
                        radius: width / 2
                        color: Theme.text
                        opacity: root.dark * (0.35 + 0.5 * Math.abs(Math.sin(twinkle.phase + index * 1.7)))
                        visible: root.dark > 0
                    }
                }

                Rectangle {
                    y: sky.h0
                    width: sky.width
                    height: sky.height - sky.h0
                    color: Qt.alpha(Theme.base, 0.5)
                }

                Rectangle {
                    y: sky.h0
                    width: sky.width
                    height: 1
                    color: Qt.alpha(Theme.text, 0.28)
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha(Theme.textSoft, 0.35)
                        strokeWidth: 1.2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [2, 4]

                        PathPolyline {
                            path: sky.joined(Sky.moonCurve, false, Sky.moon)
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha(Theme.textSoft, 0.2)
                        strokeWidth: 1.2

                        PathPolyline {
                            path: sky.joined(Sky.moonCurve, true, Sky.moon)
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha("#ffd08a", 0.45)
                        strokeWidth: 1.6
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 4]

                        PathPolyline {
                            path: sky.joined(Sky.sunCurve, false, Sky.sun)
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha("#ffc070", 0.85)
                        strokeWidth: 2

                        PathPolyline {
                            path: sky.joined(Sky.sunCurve, true, Sky.sun)
                        }
                    }
                }

                Rectangle {
                    x: sky.xOf(Sky.now)
                    width: 1
                    height: sky.height
                    color: Qt.alpha(Theme.text, 0.12)
                }

                MoonDisc {
                    readonly property real s: 22
                    x: sky.xOf(Sky.now) - s / 2
                    y: sky.yOf(Sky.moon.altitude) - s / 2
                    width: s
                    height: s
                    fraction: Sky.illumination.fraction
                    phase: Sky.illumination.phase
                    south: Sky.latitude < 0
                    shade: Theme.base
                    opacity: Sky.moon.altitude < 0 ? 0.4 : 1
                }

                Item {
                    id: sunBody
                    readonly property color tone: root.sunAlt > 12 ? "#fff1cc" : root.sunAlt > 0 ? Qt.tint("#ffb060", Qt.alpha("#fff1cc", root.sunAlt / 12)) : "#ff8e4f"
                    x: sky.xOf(Sky.now) - width / 2
                    y: sky.yOf(root.sunAlt) - height / 2
                    width: 70
                    height: 70
                    opacity: root.sunAlt < 0 ? 0.45 : 1

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: -1
                            fillGradient: RadialGradient {
                                centerX: 35
                                centerY: 35
                                focalX: 35
                                focalY: 35
                                centerRadius: 35
                                GradientStop {
                                    position: 0
                                    color: Qt.alpha(sunBody.tone, 0.55)
                                }
                                GradientStop {
                                    position: 0.35
                                    color: Qt.alpha(sunBody.tone, 0.16)
                                }
                                GradientStop {
                                    position: 1
                                    color: "transparent"
                                }
                            }

                            PathAngleArc {
                                centerX: 35
                                centerY: 35
                                radiusX: 35
                                radiusY: 35
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: Tokens.r(10)
                        antialiasing: true
                        color: sunBody.tone
                        border.width: 2
                        border.color: Qt.alpha("#ffffff", 0.55)
                    }
                }

                Repeater {
                    model: ["00", "06", "12", "18", "24"]
                    delegate: Text {
                        required property string modelData
                        required property int index
                        x: Math.max(8, Math.min(sky.width - width - 8, sky.width * index / 4 - width / 2))
                        y: sky.height - height - 6
                        text: modelData
                        color: Theme.textDim
                        opacity: 0.8
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.tinySize
                    }
                }
            }

            Timer {
                id: twinkle
                property real phase: 0
                interval: 120
                repeat: true
                running: root.shown && root.dark > 0
                onTriggered: phase += 0.09
            }
        }

        Row {
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Tokens.gap

            Repeater {
                model: [
                    {
                        glyph: Icons.GLYPHS.sunrise,
                        label: "Sunrise",
                        value: root.hhmm(Sky.sunTimes.rise)
                    },
                    {
                        glyph: Icons.GLYPHS.sunset,
                        label: "Sunset",
                        value: root.hhmm(Sky.sunTimes.set)
                    },
                    {
                        glyph: Icons.GLYPHS.daylight,
                        label: "Daylight",
                        value: root.daylightText()
                    }
                ]
                delegate: Item {
                    required property var modelData
                    width: (leftColumn.width - Tokens.gap * 2) / 3
                    height: Tokens.clockChipHeight

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusRow
                        inner: true
                        offBorder: Theme.cardLine
                    }

                    Glyph {
                        x: 14
                        y: 14
                        text: modelData.glyph
                        size: 18
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        x: 40
                        y: 13
                        text: modelData.label
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }

                    Text {
                        textFormat: Text.PlainText
                        x: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        text: modelData.value
                        color: Theme.text
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.titleSize
                        font.weight: Tokens.titleWeight
                    }
                }
            }
        }
    }

    Item {
        id: rightColumn
        x: leftColumn.x + leftColumn.width + Tokens.clockColumnGap
        y: 22 + 14 * (1 - M.stagger(root.phase, 1, 3, Tokens.staggerSpread))
        width: parent.width - x - Tokens.panelPaddingX
        height: Tokens.clockHeight - 44
        opacity: M.stagger(root.phase, 1, 3, Tokens.staggerSpread)

        Item {
            id: moonCard
            width: parent.width
            height: Tokens.clockMoonHeight

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
                offBorder: Theme.cardLine
            }

            DayAgenda {
                anchors.fill: parent
                anchors.margins: Tokens.cardPadding
                day: root.picked
                rows: 4
                opacity: root.picked !== "" ? 1 : 0
                visible: opacity > 0
                onClosed: root.picked = ""

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.fadeDuration
                    }
                }
            }

            MoonDisc {
                id: bigMoon
                opacity: root.picked === "" ? 1 : 0
                scale: 0.8 + 0.2 * opacity

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.fadeDuration
                    }
                }
                x: Tokens.cardPadding + 2
                anchors.verticalCenter: parent.verticalCenter
                width: 92
                height: 92
                fraction: Sky.illumination.fraction
                phase: Sky.illumination.phase
                south: Sky.latitude < 0
                shade: Theme.base
            }

            Column {
                anchors.left: bigMoon.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: Tokens.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                opacity: bigMoon.opacity
                visible: opacity > 0

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: Sky.phaseName
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    text: Math.round(Sky.illumination.fraction * 100) + "% illuminated"
                    color: Theme.textSoft
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.moonNext()
                    wrapMode: Text.WordWrap
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }

                Text {
                    textFormat: Text.PlainText
                    topPadding: 4
                    text: "↑ " + root.hhmm(Sky.moonTimes.rise) + "    ↓ " + root.hhmm(Sky.moonTimes.set)
                    color: Theme.textSoft
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.smallSize
                }
            }
        }

        Item {
            anchors.top: moonCard.bottom
            anchors.topMargin: Tokens.gap + 4
            anchors.bottom: parent.bottom
            width: parent.width

            Text {
                textFormat: Text.PlainText
                id: monthTitle
                x: 4
                text: Qt.locale().standaloneMonthName(root.month, Locale.LongFormat) + " " + root.year
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.year = root.now.getFullYear();
                        root.month = root.now.getMonth();
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: monthTitle.verticalCenter
                spacing: 16

                Repeater {
                    model: [-1, 1]
                    delegate: Glyph {
                        required property int modelData
                        text: modelData < 0 ? Icons.GLYPHS.chevronLeft : Icons.GLYPHS.chevronRight
                        size: 22
                        color: Theme.accent

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shift(modelData)
                        }
                    }
                }
            }

            Grid {
                id: grid
                readonly property real cell: (parent.width - 6 * columnSpacing) / 7
                anchors.bottom: parent.bottom
                columns: 7
                columnSpacing: 4
                rowSpacing: 2

                Repeater {
                    model: root.labels
                    delegate: Text {
                        required property string modelData
                        width: grid.cell
                        height: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }
                }

                Repeater {
                    model: root.cells
                    delegate: Item {
                        id: dayCell
                        required property var modelData
                        readonly property bool isToday: C.isSameDay(modelData, root.now)
                        readonly property string key: root.keyOf(modelData)
                        readonly property int count: root.busy[dayCell.key] || 0
                        width: grid.cell
                        height: Tokens.clockDayHeight

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.height + 4
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.accent
                            opacity: root.picked === dayCell.key ? 1 : dayArea.containsMouse ? 0.4 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Tokens.stateDuration
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -3
                            width: dayCell.count > 1 ? 9 : 4
                            height: 4
                            radius: Tokens.r(2)
                            visible: dayCell.count > 0
                            color: dayCell.isToday ? Theme.onAccent : Theme.accent
                            z: 2
                        }

                        MouseArea {
                            id: dayArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked = root.picked === dayCell.key || !Diver.plugged ? "" : dayCell.key
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.height
                            height: parent.height
                            radius: height / 2
                            antialiasing: true
                            color: Theme.accent
                            visible: parent.isToday
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            text: modelData.day
                            color: parent.isToday ? Theme.onAccent : Theme.text
                            opacity: modelData.inMonth ? 1 : 0.35
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                            font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }

    Item {
        id: weatherCard
        readonly property var d: Weather.data
        readonly property var hours: weatherCard.d === null ? [] : weatherCard.d.hours.slice(0, 10)
        readonly property real lo: Math.min(...weatherCard.hours.map(h => h.temp), 99)
        readonly property real hi: Math.max(...weatherCard.hours.map(h => h.temp), -99)
        visible: Weather.enabled
        x: Tokens.panelPaddingX
        y: Tokens.clockHeight - 22 + Tokens.gap + 14 * (1 - M.stagger(root.phase, 2, 3, Tokens.staggerSpread))
        width: parent.width - Tokens.panelPaddingX * 2
        height: Tokens.clockWeatherHeight
        opacity: M.stagger(root.phase, 2, 3, Tokens.staggerSpread)

        function tempY(t: real): real {
            const span = Math.max(1, weatherCard.hi - weatherCard.lo);
            return 40 - (t - weatherCard.lo) / span * 26;
        }

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusCard
            inner: true
            offBorder: Theme.cardLine
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusCard
            visible: weatherCard.d !== null
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(weatherCard.d !== null && weatherCard.d.day ? Theme.accent : Theme.accentDeep, 0.16)
                }
                GradientStop {
                    position: 0.45
                    color: "transparent"
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: weatherCard.d === null
            text: Weather.error !== "" ? Weather.error : !Sky.available ? "Set a location to see the weather" : "Fetching the forecast…"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
        }

        Item {
            id: nowBlock
            visible: weatherCard.d !== null
            x: 20
            y: 16
            width: 200
            height: 96

            Glyph {
                id: nowGlyph
                text: Weather.now === null ? "" : Icons.GLYPHS[Weather.now.glyph]
                size: 44
                color: Theme.accent

                SequentialAnimation on anchors.topMargin {
                    running: root.shown && !Tokens.paused
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: -3
                        duration: Tokens.loopMs(1800)
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 3
                        duration: Tokens.loopMs(1800)
                        easing.type: Easing.InOutSine
                    }
                }
                anchors.top: parent.top
            }

            Text {
                textFormat: Text.PlainText
                anchors.left: nowGlyph.right
                anchors.leftMargin: 12
                anchors.verticalCenter: nowGlyph.verticalCenter
                text: weatherCard.d === null ? "" : weatherCard.d.temp + "°"
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: 44
                font.weight: Font.DemiBold
                font.letterSpacing: -1
            }

            Column {
                anchors.bottom: parent.bottom
                spacing: 2

                Text {
                    textFormat: Text.PlainText
                    text: Weather.now === null ? "" : Weather.now.label + (root.place() !== "" ? " · " + root.place() : "")
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    text: weatherCard.d === null ? "" : "Feels " + weatherCard.d.feels + "° · " + weatherCard.d.humidity + "% · " + weatherCard.d.wind + " " + weatherCard.d.windUnit
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
        }

        Item {
            id: hourly
            visible: weatherCard.d !== null
            x: nowBlock.x + nowBlock.width + 20
            y: 14
            width: parent.width - x - 16
            height: 104
            readonly property real col: hourly.width / Math.max(1, weatherCard.hours.length)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: weatherCard.hours.length > 1

                ShapePath {
                    strokeColor: Qt.alpha(Theme.accent, 0.7)
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: weatherCard.hours.map((h, i) => Qt.point(hourly.col * (i + 0.5), 34 + weatherCard.tempY(h.temp)))
                    }
                }
            }

            Repeater {
                model: weatherCard.hours

                delegate: Item {
                    required property var modelData
                    required property int index
                    x: hourly.col * index
                    width: hourly.col
                    height: hourly.height
                    opacity: Math.max(0, Math.min(1, root.phase * 3 - 1.2 - index * 0.08))

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: modelData.time
                        color: Theme.textDim
                        font.family: Tokens.fontMono
                        font.pixelSize: 11
                    }

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        text: Icons.GLYPHS[Wx.describe(modelData.code, modelData.day).glyph]
                        size: 16
                        color: Theme.textSoft
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 34 + weatherCard.tempY(modelData.temp) - 3
                        width: 6
                        height: 6
                        radius: Tokens.r(3)
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        text: modelData.temp + "°"
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                        font.weight: Font.DemiBold
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        visible: modelData.rain >= 20
                        text: modelData.rain + "%"
                        color: Qt.lighter(Theme.accent, 1.2)
                        font.family: Tokens.fontUi
                        font.pixelSize: 10
                    }
                }
            }
        }

        Divider {
            visible: weatherCard.d !== null
            x: 20
            y: 126
            width: parent.width - 40
        }

        Row {
            visible: weatherCard.d !== null
            x: 20
            y: 134
            width: parent.width - 40
            height: parent.height - y - 8

            Repeater {
                model: weatherCard.d === null ? [] : weatherCard.d.days.slice(0, 6)

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: parent.width / 6
                    height: parent.height

                    Text {
                        textFormat: Text.PlainText
                        id: dayName
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                        color: index === 0 ? Theme.text : Theme.textSoft
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                        font.weight: index === 0 ? Font.DemiBold : Font.Normal
                    }

                    Glyph {
                        id: dayGlyph
                        anchors.left: dayName.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS[Wx.describe(modelData.code, true).glyph]
                        size: 16
                        color: Theme.accent
                    }

                    Text {
                        anchors.left: dayGlyph.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.max + "° <font color=\"" + Theme.textDim + "\">" + modelData.min + "°</font>"
                        textFormat: Text.StyledText
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }
                }
            }
        }
    }
}
