import QtQuick
import SylStack
import qs.services
import "../lib/widgets.mjs" as Wd

PanelWindow {
    id: win

    required property var modelData
    required property var host
    required property var screenData
    readonly property var item: win.host ? win.host.find(win.modelData) : null
    readonly property var cfg: win.host ? win.host.cfg : null
    readonly property var rect: !win.item || !win.cfg || !win.screenData ? null : Wd.place(win.item, [
        {
            name: win.screenData.name,
            width: win.screenData.width,
            height: win.screenData.height
        }
    ], win.cfg.cell, win.cfg.gap)
    readonly property var desk: win.screenData ? Compositor.workspaces.find(w => w.output === win.screenData.name && w.active) : undefined
    readonly property var front: Compositor.activeWindow
    readonly property bool covered: !!win.item && !!win.host && win.item.hideFullscreen === true && !!win.front && (win.front.fullscreen === true || win.front.maximized === true) && win.host.focusedScreen === win.screenData.name
    readonly property bool atDesk: !win.item || !win.item.workspaces || win.item.workspaces.length === 0 || win.desk !== undefined && (win.item.workspaces.indexOf(win.desk.name) >= 0 || win.item.workspaces.indexOf(win.desk.index) >= 0)
    readonly property bool paused: win.covered || !win.atDesk

    screen: win.screenData
    visible: win.rect !== null && !win.paused
    anchors {
        top: true
        left: true
    }
    margins {
        top: win.rect === null ? 0 : win.rect.y
        left: win.rect === null ? 0 : win.rect.x
    }
    implicitWidth: win.rect === null ? 1 : win.rect.w
    implicitHeight: win.rect === null ? 1 : win.rect.h
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: win.item !== null && win.item.layer === "overlay" ? WlrLayer.Overlay : win.item !== null && win.item.layer === "above" ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "sylwidget-" + win.modelData
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        width: win.item !== null && win.item.clickThrough ? 0 : win.width
        height: win.item !== null && win.item.clickThrough ? 0 : win.height
    }
    BackgroundEffect.blurRegion: Resin.enabled && !frame.clear ? blur : null

    Region {
        id: blur
        width: win.width
        height: win.height
        radius: frame.radius
    }

    WidgetFrame {
        id: frame
        anchors.fill: parent
        item: win.item
        cfg: win.cfg
        paused: win.paused
        host: win.host
        rect: win.rect
        screenName: win.screenData ? win.screenData.name : ""
    }
}
