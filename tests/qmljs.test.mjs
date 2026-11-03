import { test } from "node:test"
import assert from "node:assert/strict"
import { readdirSync, readFileSync } from "node:fs"

test("shell/lib avoids JavaScript that the QML engine does not have", () => {
    const dir = new URL("../shell/lib/", import.meta.url)
    for (const f of readdirSync(dir).filter(f => f.endsWith(".mjs"))) {
        const text = readFileSync(new URL(f, dir), "utf8")
        for (const bad of ["Object.fromEntries", "Object.hasOwn(", ".flatMap(", "structuredClone(", ".replaceAll("])
            assert.ok(text.indexOf(bad) < 0, f + " uses " + bad)
    }
})
