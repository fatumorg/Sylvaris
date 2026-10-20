import { test } from "node:test"
import assert from "node:assert/strict"
import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"

function qmlFiles(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? qmlFiles(join(dir, e.name)) : e.name.endsWith(".qml") ? [join(dir, e.name)] : [])
}

test("every animation takes its timing and curve from Tokens so styles, speed and lite mode reach it", () => {
    const bad = []
    for (const f of qmlFiles(new URL("../shell", import.meta.url).pathname)) {
        readFileSync(f, "utf8").split("\n").forEach((line, i) => {
            if (/^\s*duration:\s*\d/.test(line) || /Easing\.(OutCubic|InCubic)\b/.test(line))
                bad.push(f.slice(f.indexOf("shell/")) + ":" + (i + 1) + " " + line.trim())
        })
    }
    assert.deepEqual(bad, [])
})
