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

test("Tokens has no fixed radius left, so looks can reshape every corner", () => {
    const text = readFileSync(new URL("../shell/Tokens.qml", import.meta.url), "utf8")
    assert.doesNotMatch(text, /int \w*[rR]adius\w*: \d+$/m)
})

test("no part paints a literal corner radius outside Tokens", () => {
    const bad = []
    for (const f of qmlFiles(new URL("../shell", import.meta.url).pathname)) {
        readFileSync(f, "utf8").split("\n").forEach((line, i) => {
            if (/^\s*radius:\s*[1-9]\d*\s*$/.test(line))
                bad.push(f.slice(f.indexOf("shell/")) + ":" + (i + 1))
        })
    }
    assert.deepEqual(bad, [])
})
