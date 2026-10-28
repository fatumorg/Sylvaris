import QtQuick
import QtQuick.Effects
import SylStack
import qs
import qs.services
import "../lib/paper.mjs" as W
import "../lib/settings.mjs" as S

PanelWindow {
    id: root

    required property var modelData
    property var host: null
    readonly property var cfg: Settings.at(root.modelData.name).paper
    readonly property string path: S.expandHome(W.resolve(root.cfg, Theme.currentId, Theme.wallpaper, root.modelData.name), Stack.env("HOME"))
    property bool flip: false
    property real mix: 1
    readonly property bool gpu: root.contentItem.GraphicsInfo.api !== GraphicsInfo.Software && root.contentItem.GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property int desk: {
        const w = Compositor.workspaces.find(w => w.output === root.modelData.name && w.active);
        return w === undefined ? -1 : w.index;
    }
    property int lastDesk: -1
    property real shift: 0

    onDeskChanged: {
        if (root.lastDesk >= 0 && root.desk >= 0 && root.cfg.parallax > 0 && !Tokens.lite && Tokens.motion >= 0.05) {
            away.to = (root.desk > root.lastDesk ? -1 : 1) * root.cfg.parallax * 0.02 * root.width;
            sway.restart();
        }
        root.lastDesk = root.desk;
    }

    screen: root.modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.base
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "sylpaper"

    function load(): void {
        const next = root.flip ? a : b;
        if (next.source.toString() === "file://" + root.path && next.status === Image.Ready) {
            root.swap();
            return;
        }
        next.source = root.path === "" ? "" : "file://" + root.path;
    }

    function swap(): void {
        root.flip = !root.flip;
        root.mix = 0;
        if (root.cfg.transition === "none" || root.cfg.duration === 0 || Tokens.lite)
            root.mix = 1;
        else
            mixAnim.restart();
    }

    onPathChanged: root.load()
    Component.onCompleted: {
        a.source = root.path === "" ? "" : "file://" + root.path;
        root.flip = false;
    }

    NumberAnimation {
        id: mixAnim
        target: root
        property: "mix"
        from: 0
        to: 1
        duration: Math.round(root.cfg.duration * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.moveCurve
    }

    SequentialAnimation {
        id: sway

        NumberAnimation {
            id: away
            target: root
            property: "shift"
            duration: Tokens.ms(200)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.moveCurve
        }

        NumberAnimation {
            target: root
            property: "shift"
            to: 0
            duration: Tokens.ms(620)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.springCurve
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        scale: 1 + Math.abs(root.shift) * 2 / Math.max(1, root.width)
        transform: Translate {
            x: root.shift
        }
        layer.enabled: root.gpu && root.cfg.blur > 0 && !Tokens.lite
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.cfg.blur
            blurMax: 64
        }

        Image {
            id: a
            readonly property bool front: !root.flip
            anchors.fill: parent
            fillMode: W.fillMode(root.cfg.fit)
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: root.width
            sourceSize.height: root.cfg.fit === "cover" ? root.height : 0
            z: a.front ? 1 : 0
            opacity: a.front ? (root.cfg.transition === "slide" ? 1 : root.mix) : 1
            scale: a.front && root.cfg.transition === "zoom" ? 1.08 - 0.08 * root.mix : 1
            x: a.front && root.cfg.transition === "slide" ? root.width * (1 - root.mix) : 0
            onStatusChanged: {
                if (status === Image.Ready && !a.front && root.path !== "" && source.toString() === "file://" + root.path)
                    root.swap();
            }
        }

        Image {
            id: b
            readonly property bool front: root.flip
            anchors.fill: parent
            fillMode: W.fillMode(root.cfg.fit)
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: root.width
            sourceSize.height: root.cfg.fit === "cover" ? root.height : 0
            z: b.front ? 1 : 0
            opacity: b.front ? (root.cfg.transition === "slide" ? 1 : root.mix) : 1
            scale: b.front && root.cfg.transition === "zoom" ? 1.08 - 0.08 * root.mix : 1
            x: b.front && root.cfg.transition === "slide" ? root.width * (1 - root.mix) : 0
            onStatusChanged: {
                if (status === Image.Ready && !b.front && root.path !== "" && source.toString() === "file://" + root.path)
                    root.swap();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.cfg.tint > 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.accent, root.cfg.tint * 0.5)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.accentDeep, root.cfg.tint * 0.35)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.cfg.dim > 0
        color: Qt.alpha("#000000", root.cfg.dim)
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.host !== null
        acceptedButtons: Qt.RightButton
        onClicked: m => root.host.showMenu(root.modelData, m.x, m.y)
    }
}
