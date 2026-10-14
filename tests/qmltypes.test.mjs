import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { join, basename } from "node:path"

const ROOT = new URL("../shell/", import.meta.url).pathname
const EXTERNAL = new Set(["AnimatedImage", "AudioOutput", "Binding", "Canvas", "ColorAnimation", "Column", "Component", "ConicalGradient", "Connections", "DragHandler", "DropArea", "FileView", "Flickable", "FloatingWindow", "Flow", "FocusScope", "FolderListModel", "FontMetrics", "FrameAnimation", "Gradient", "GradientStop", "Grid", "GridView", "HoverHandler", "IconImage", "Image", "Instantiator", "IpcHandler", "Item", "LazyLoader", "ListModel", "ListView", "Loader", "MediaPlayer", "MouseArea", "MultiEffect", "NotificationServer", "NumberAnimation", "PamContext", "PanelWindow", "ParallelAnimation", "Path", "PathAngleArc", "PathArc", "PathAttribute", "PathPolyline", "PathQuad", "PathRectangle", "PathView", "PauseAnimation", "PolkitAgent", "PopupWindow", "Process", "PwObjectTracker", "QsMenuOpener", "QtObject", "RadialGradient", "Rectangle", "Region", "Repeater", "Rotation", "Row", "Scale", "Scope", "ScreencopyView", "ScriptAction", "SequentialAnimation", "ShaderEffectSource", "Shape", "ShapePath", "ShellRoot", "Shortcut", "Singleton", "Socket", "SocketServer", "SplitParser", "StdioCollector", "TapHandler", "Text", "TextEdit", "TextInput", "TextMetrics", "Timer", "Transition", "Translate", "Variants", "VideoOutput", "WheelHandler", "WlSessionLock", "WlSessionLockSurface"])
const USE = /(?:^\s*|:\s*)([A-Z][A-Za-z0-9_]*)\s*\{/
const INLINE = /^\s*component\s+([A-Z]\w*)\s*:/

function walk(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(join(dir, e.name)) : e.name.endsWith(".qml") ? [join(dir, e.name)] : [])
}

test("every QML type in the shell is a Sylvaris file, an inline component or a known Qt or Quickshell type", () => {
    const files = walk(ROOT)
    const texts = files.map(f => readFileSync(f, "utf8"))
    const local = new Set(files.map(f => basename(f, ".qml")))
    for (const text of texts)
        for (const line of text.split("\n")) {
            const m = INLINE.exec(line)
            if (m)
                local.add(m[1])
        }
    const unknown = []
    files.forEach((f, i) => texts[i].split("\n").forEach((line, n) => {
        const m = USE.exec(line)
        if (m && !local.has(m[1]) && !EXTERNAL.has(m[1]))
            unknown.push(f.slice(ROOT.length) + ":" + (n + 1) + ": " + m[1])
    }))
    assert.deepEqual(unknown, [], "unknown types; a new Qt or Quickshell type goes in EXTERNAL")
})
