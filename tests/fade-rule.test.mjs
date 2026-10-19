import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { join } from "node:path"

const ROOT = new URL("../shell/", import.meta.url).pathname
const HIDE = /^\s*(\w+)\.opacity = 0;$/

test("a closing card stops its open animation first", () => {
    const offenders = []
    for (const file of readdirSync(ROOT, { recursive: true }).filter(f => f.endsWith(".qml"))) {
        const lines = readFileSync(join(ROOT, file), "utf8").split("\n")
        const anim = lines.findIndex(l => l.trim() === "id: showAnim")
        if (anim < 0)
            continue
        const target = lines.slice(anim).find(l => l.trim().startsWith("target:")).trim().slice(8).trim()
        lines.forEach((line, i) => {
            const hide = line.match(HIDE)
            if (hide && hide[1] === target && lines[i - 1].trim() !== "showAnim.stop();")
                offenders.push(file + ":" + (i + 1))
        })
    }
    assert.deepEqual(offenders, [])
})
