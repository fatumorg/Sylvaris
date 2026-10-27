import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { join, basename } from "node:path"

const ROOT = new URL("../shell/", import.meta.url).pathname
const STACK = new URL("../stack/", import.meta.url).pathname
const QT = new Set(["AnimatedImage", "AudioOutput", "Binding", "Canvas", "ColorAnimation", "Column", "Component", "ConicalGradient", "Connections", "DragHandler", "DropArea", "Flickable", "Flow", "FocusScope", "FolderListModel", "FontMetrics", "FrameAnimation", "Gradient", "GradientStop", "Grid", "GridView", "HoverHandler", "Image", "Instantiator", "Item", "ListModel", "ListView", "Loader", "MediaPlayer", "MouseArea", "MultiEffect", "NumberAnimation", "ParallelAnimation", "Path", "PathAngleArc", "PathArc", "PathAttribute", "PathPolyline", "PathQuad", "PathRectangle", "PathView", "PauseAnimation", "QtObject", "RadialGradient", "Rectangle", "Repeater", "Rotation", "Row", "Scale", "ScriptAction", "SequentialAnimation", "ShaderEffectSource", "Shape", "ShapePath", "Shortcut", "TapHandler", "Text", "TextEdit", "TextInput", "TextMetrics", "Timer", "Transition", "Translate", "VideoOutput", "WheelHandler"])

export function stackTypes() {
    const out = new Set(readdirSync(join(STACK, "qml")).filter(f => f.endsWith(".qml")).map(f => basename(f, ".qml")))
    for (const f of readdirSync(join(STACK, "src")).filter(f => f.endsWith(".h")))
        for (const m of readFileSync(join(STACK, "src", f), "utf8").matchAll(/class\s+(\w+)\s*:[^{]*\{\s*Q_OBJECT\s*QML_ELEMENT/g))
            out.add(m[1])
    return out
}

const EXTERNAL = new Set([...QT, ...stackTypes()])
const USE = /(?:^\s*|:\s*)([A-Z][A-Za-z0-9_]*)\s*\{/
const INLINE = /^\s*component\s+([A-Z]\w*)\s*:/

function walk(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(join(dir, e.name)) : e.name.endsWith(".qml") ? [join(dir, e.name)] : [])
}

test("every QML type in the shell is a Sylvaris file, an inline component, a known Qt type or a SylStack type", () => {
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
    assert.deepEqual(unknown, [], "unknown types; a new Qt type goes in QT, a SylStack type needs QML_ELEMENT")
})
