pragma Singleton

import QtQuick
import SylStack
import "lib/motion.mjs" as M
import "lib/look.mjs" as L

Singleton {
    id: root

    property real motion: 1
    property string preset: "smooth"
    property string openStyle: "grow"
    property real staggerSpread: 0.35
    property real springiness: -1
    property var tap: null
    readonly property var curves: M.presetTokens(root.preset)
    property bool lite: false
    property bool paused: false
    property bool iconTint: true
    property real textScale: 1
    property real radiusScale: 1
    property string corners: "round"
    property real densityScale: 1
    property string fontUiName: "Inter"
    property string fontMonoName: "JetBrainsMono Nerd Font"
    property string fontDisplayName: "Inter"
    readonly property string fontGlyph: "JetBrainsMono Nerd Font"
    property int titleWeight: Font.DemiBold
    property string toggleStyle: "pill"
    property string sliderStyle: "line"
    property string segmentedStyle: "boxed"
    property string buttonStyle: "solid"
    property string cardStyle: "solid"
    property string hoverStyle: "glow"
    property string iconStyle: "plain"
    property string dividerStyle: "hairline"
    property int labelCase: Font.MixedCase
    property real tracking: 0
    property real borderWidth: 0
    property real accentStrength: 0.5
    readonly property real pace: root.lite ? 0.55 : root.motion * root.curves.pace
    readonly property int enterDuration: Math.round(340 * root.pace)
    readonly property int exitDuration: Math.round(190 * root.pace)
    readonly property int moveDuration: Math.round(420 * root.pace)
    readonly property int staggerStep: Math.round(22 * root.pace)
    readonly property var enterCurve: root.curves.enter
    readonly property var exitCurve: root.curves.exit
    readonly property var moveCurve: root.curves.move
    readonly property var springCurve: root.springiness >= 0 ? M.springCurve(root.springiness) : root.curves.spring
    readonly property int centerCompactWidth: 460
    readonly property int centerExpandedWidth: 620
    readonly property int centerHeight: 660
    readonly property int edgeMargin: Math.round(12 * root.densityScale)
    readonly property int panelPaddingX: Math.round(28 * root.densityScale)
    readonly property int panelPaddingY: Math.round(30 * root.densityScale)
    readonly property int gap: Math.round(12 * root.densityScale)
    readonly property int headerGap: Math.round(16 * root.densityScale)
    readonly property int radiusPanel: Math.round(24 * root.radiusScale)
    readonly property int radiusCard: Math.round(18 * root.radiusScale)
    readonly property int radiusTile: Math.round(18 * root.radiusScale)
    readonly property int radiusRow: Math.round(14 * root.radiusScale)
    readonly property int radiusNode: Math.round(16 * root.radiusScale)
    readonly property int radiusGlass: Math.round(28 * root.radiusScale)
    readonly property int tileHeight: Math.round(76 * root.densityScale)
    readonly property int tileIcon: 44
    readonly property int tileIconRadius: Math.round(14 * root.radiusScale)
    readonly property int tileIconFont: 22
    readonly property int rowHeight: Math.round(52 * root.densityScale)
    readonly property int sliderHeight: Math.round(44 * root.densityScale)
    readonly property int avatarSize: 56
    readonly property int artSize: 64
    readonly property int cardPadding: Math.round(14 * root.densityScale)
    readonly property int clockSize: Math.round(52 * root.textScale)
    readonly property int dateSize: Math.round(17 * root.textScale)
    readonly property int titleSize: Math.round(17 * root.textScale)
    readonly property int bodySize: Math.round(15 * root.textScale)
    readonly property int nodeSize: Math.round(14 * root.textScale)
    readonly property int smallSize: Math.round(13 * root.textScale)
    readonly property int tinySize: Math.round(12 * root.textScale)
    readonly property string fontUi: root.fontUiName
    readonly property string fontMono: root.fontMonoName
    readonly property string fontDisplay: root.fontDisplayName
    readonly property int openDuration: root.enterDuration
    readonly property int morphDuration: Math.round(520 * root.pace)
    readonly property int fadeDuration: Math.round(260 * root.pace)
    readonly property int nodeMoveDuration: Math.round(450 * root.pace)
    readonly property int colorDuration: Math.round(400 * root.pace)
    readonly property int stateDuration: Math.round(160 * root.pace)
    readonly property int previewDelay: 500

    function blur(base: real): real {
        return root.lite ? base : L.blurRadius(base, root.corners);
    }

    function r(base: real): int {
        return Math.round(base * root.radiusScale);
    }

    function ms(base: real): int {
        return Math.max(1, Math.round(base * root.pace));
    }

    function loopMs(base: real): int {
        return Math.max(1, Math.round(base * (root.motion < 0.05 ? 1 : root.motion) * root.curves.pace));
    }
    readonly property int themeCardWidth: 560
    readonly property int themeCardHeight: 760
    readonly property int themeRingX: 900
    readonly property int themeRingY: 220
    readonly property int themeRingCenterY: 480
    readonly property int themeNameSize: 190
    readonly property int themeRadius: Math.round(36 * root.radiusScale)
    readonly property var morphCurve: [0.2, 0.8, 0.2, 1, 1, 1]
    readonly property int haloSize: 118
    readonly property int haloRim: 3
    readonly property int haloRimOffset: 9
    readonly property int coreLabelOffset: 78
    readonly property int orbitCenterY: 282
    readonly property int nodeLabelMax: 130
    readonly property int segmentedSide: 140
    readonly property int segmentedBottom: 22
    readonly property int segmentedHeight: 50
    readonly property int powerSize: 46
    readonly property int moonSize: 38
    readonly property int clockWidth: 780
    readonly property int clockHeight: 440
    readonly property int clockSkyWidth: 410
    readonly property int clockSkyHeight: 208
    readonly property int clockColumnGap: 20
    readonly property int clockChipHeight: 72
    readonly property int clockMoonHeight: 172
    readonly property int clockWeatherHeight: 196
    readonly property int clockDayHeight: 24
    readonly property int notifyIcon: 36
    readonly property int notifyThumb: 56
    readonly property int toastWidth: 400
    readonly property int toastGap: Math.round(10 * root.densityScale)
    readonly property int notifyWidth: 440
    readonly property int notifyHeight: 640
    readonly property int padIcon: 88
    readonly property int padCellWidth: 180
    readonly property int padCellHeight: 176
    readonly property int padSearchWidth: 440
    readonly property int padSearchHeight: 50
    readonly property int padListWidth: 640
    readonly property int padListRow: Math.round(54 * root.densityScale)
    readonly property int barHeight: 46
    readonly property int barMargin: 10
    readonly property int barRadius: Math.round(18 * root.radiusScale)
    readonly property int barPadding: Math.round(6 * root.densityScale)
    readonly property int barGap: Math.round(4 * root.densityScale)
    readonly property int barItemHeight: 34
    readonly property int barGlyph: 17
    readonly property int barText: 14
    readonly property int barTitleMax: 360
    readonly property int barMediaMax: 240
    readonly property int deckPadding: Math.round(9 * root.densityScale)
    readonly property int deckMargin: 10
    readonly property int deckRadius: Math.round(24 * root.radiusScale)
    readonly property int deckMenuWidth: 240
    readonly property int mediaWidth: 500
    readonly property int mediaHeight: 740
    readonly property int mediaArt: 140
    readonly property int eqHeight: 150
    readonly property int settingsWidth: 1080
    readonly property int paperWidth: 980
    readonly property int paperHeight: 680
    readonly property int diverWidth: 980
    readonly property int switchCardWidth: 260
    readonly property int switchIconCard: 128
    readonly property int clipWidth: 540
    readonly property int clipHeight: 580
    readonly property int captureWidth: 460
    readonly property int captureHeight: 300
    readonly property int accessWidth: 560
    readonly property int accessHeight: 660
    readonly property int pluginsWidth: 720
    readonly property int pluginsHeight: 520
    readonly property int testWidth: 460
    readonly property int testHeight: 660
    readonly property int rgbWidth: 480
    readonly property int rgbHeight: 720
    readonly property int tempWidth: 480
    readonly property int tempHeight: 720
    readonly property int diverHeight: 720
    readonly property int settingsHeight: 760
    readonly property int settingsSidebar: 250
    readonly property int settingsRow: Math.round(58 * root.densityScale)
}
