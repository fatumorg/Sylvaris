import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { INDEX, searchSettings } from "../shell/lib/settingsIndex.mjs"
import { SECTIONS } from "../shell/lib/sections.mjs"

const shell = join(dirname(fileURLToPath(import.meta.url)), "..", "shell")
const files = readdirSync(join(shell, "settings")).filter(f => f.endsWith(".qml")).map(f => join(shell, "settings", f))
    .concat(["diver/DiverPage.qml", "fatest/FaTestPage.qml", "rgb/RGBPage.qml"].map(f => join(shell, "plugins", f)))

function rows() {
    const out = []
    for (const f of files) {
        const lines = readFileSync(f, "utf8").split("\n")
        lines.forEach((line, i) => {
            if (!/SettingRow \{\s*$/.test(line))
                return
            const props = {}
            for (let j = i + 1; j < lines.length && !/\{\s*$/.test(lines[j]) && !/^\s*\}/.test(lines[j]); j++) {
                const m = lines[j].match(/^\s*(key|title|advanced): (.*)$/)
                if (m)
                    props[m[1]] = m[2]
            }
            out.push(Object.assign({ file: f.split("/").pop() }, props))
        })
    }
    return out
}

const literal = v => v !== undefined && /^"[^"]*"$/.test(v) ? JSON.parse(v) : null

test("every row with a literal key is in the index with its title and detail", () => {
    for (const r of rows()) {
        const key = literal(r.key)
        if (key === null)
            continue
        const hits = INDEX.filter(e => e.key === key)
        assert.ok(hits.length > 0, r.file + " " + key + " is not indexed")
        const title = literal(r.title)
        if (title !== null)
            assert.ok(hits.some(e => e.title === title), r.file + " " + key + " is indexed as " + hits.map(e => e.title).join(", "))
        assert.equal(hits.some(e => e.advanced === (r.advanced === "true")), true, r.file + " " + key + " advanced")
    }
})

test("every indexed key is a row key or names a title the pages show", () => {
    const keys = new Set(rows().map(r => literal(r.key)).filter(k => k !== null))
    const source = files.map(f => readFileSync(f, "utf8")).join("\n")
    for (const e of INDEX) {
        if (e.key.startsWith("parts.") || e.key.startsWith("sync.targets."))
            continue
        assert.ok(keys.has(e.key) || source.includes("\"" + e.title + "\""), e.key)
    }
})

test("every row has a key", () => {
    const missing = rows().filter(r => r.key === undefined && !/^(row\.)?modelData\.label$/.test(r.title || "") && r.title !== "modelData" && !/^modelData\.(ok|timestamp)/.test(r.title || "")).map(r => r.file + " " + r.title)
    assert.deepEqual(missing, [])
})

test("every entry sits on a real tab", () => {
    const tabs = new Set(SECTIONS.map(s => s.key))
    for (const e of INDEX)
        assert.ok(tabs.has(e.tab), e.key + " " + e.tab)
})

test("searching blur puts the wallpaper blur first", () => {
    assert.equal(searchSettings("blur", {})[0].key, "paper.blur")
})

test("an empty search finds nothing", () => {
    assert.deepEqual(searchSettings("", {}), [])
    assert.deepEqual(searchSettings("   ", {}), [])
})

test("plugin tabs that are off stay out of results", () => {
    assert.equal(searchSettings("alarm", {}).some(e => e.tab === "diver"), false)
    assert.equal(searchSettings("alarm", { diver: true }).some(e => e.tab === "diver"), true)
})
