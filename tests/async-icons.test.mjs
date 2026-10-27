import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { join } from "node:path"

const ROOT = new URL("../shell/", import.meta.url).pathname
const ICON_SOURCE = /source:.*(Apps\.icon\(|iconPath\(|root\.icon\b)/

function walk(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(join(dir, e.name)) : e.name.endsWith(".qml") ? [join(dir, e.name)] : [])
}

test("icon theme images never load on the async reader thread, where QIcon is not thread safe", () => {
    const offenders = []
    for (const file of walk(ROOT)) {
        const lines = readFileSync(file, "utf8").split("\n")
        lines.forEach((line, i) => {
            if (!/^\s*asynchronous:\s*true\s*$/.test(line))
                return
            const near = lines.slice(Math.max(0, i - 12), i + 12)
            if (near.some(l => ICON_SOURCE.test(l)))
                offenders.push(file.slice(ROOT.length) + ":" + (i + 1))
        })
    }
    assert.deepEqual(offenders, [])
})
