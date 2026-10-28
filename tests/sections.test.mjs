import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { GROUPS, SECTIONS, sectionsIn, groupOf, HUBS, resolveSection, tabsIn } from "../shell/lib/sections.mjs"
import { MODULES } from "../shell/lib/modules.mjs"

const page = readFileSync(new URL("../shell/settings/SylSettings.qml", import.meta.url), "utf8")

test("sections have unique keys, a label, a glyph and a known group", () => {
    const keys = SECTIONS.map(s => s.key)
    assert.equal(new Set(keys).size, keys.length)
    for (const s of SECTIONS) {
        assert.ok(s.label.length > 0, s.key)
        assert.ok(typeof s.glyph === "string" && s.glyph.length > 0, s.key)
        assert.ok(GROUPS.some(g => g.key === s.group), s.key)
    }
})

test("every group holds at least two sections with no plugin on and none holds more than nine", () => {
    for (const g of GROUPS) {
        const n = sectionsIn(g.key, {}).length
        assert.ok(n >= 2 && n <= 9, g.key + " has " + n)
    }
})

test("the groups split the desktop by what people look for", () => {
    assert.deepEqual(GROUPS.map(g => g.key), ["system", "look", "panels", "apps", "security", "advanced"])
    assert.deepEqual(sectionsIn("look", {}).map(s => s.key), ["look", "appearance", "wallpaper", "motion", "sync"])
    assert.deepEqual(sectionsIn("security", {}).map(s => s.key), ["lock", "polkit"])
    assert.deepEqual(sectionsIn("advanced", {}).map(s => s.key), ["keybinds", "commands", "plugins"])
    assert.equal(groupOf("files"), "apps")
    assert.equal(groupOf("bar"), "panels")
    assert.equal(groupOf("displays"), "system")
    assert.equal(groupOf("nope"), "")
})

test("plugin sections show only while their plugin is on", () => {
    assert.ok(!sectionsIn("apps", {}).some(s => s.key === "diver"))
    assert.ok(sectionsIn("apps", { diver: true }).some(s => s.key === "diver"))
    assert.ok(!sectionsIn("system", { rgb: false }).some(s => s.key === "rgb"))
    assert.ok(sectionsIn("system", { rgb: true }).some(s => s.key === "rgb"))
    assert.deepEqual(sectionsIn("system", undefined).map(s => s.key), sectionsIn("system", {}).map(s => s.key))
})

test("every section has a page and every module points at a section", () => {
    for (const s of SECTIONS)
        assert.match(page, new RegExp("\\b" + s.key + ": " + "[a-z]+Page\\b"), s.key)
    for (const name of Object.keys(MODULES))
        assert.ok(SECTIONS.some(s => s.key === MODULES[name].section), name)
})

test("every section lives in exactly one hub", () => {
    for (const s of SECTIONS)
        assert.equal(HUBS.filter(h => h.tabs.includes(s.key)).length, 1, s.key)
    assert.equal(HUBS.length, 7)
})

test("resolveSection finds the hub and tab", () => {
    assert.deepEqual(resolveSection("motion"), { hub: "look", tab: "motion" })
    assert.deepEqual(resolveSection("wallpaper"), { hub: "desktop", tab: "wallpaper" })
    assert.equal(resolveSection("nope"), null)
})

test("tabsIn hides plugin tabs that are off", () => {
    assert.deepEqual(tabsIn("plugins", {}).map(s => s.key), ["plugins"])
    assert.deepEqual(tabsIn("plugins", { diver: true, rgb: true }).map(s => s.key), ["plugins", "diver", "rgb"])
    assert.deepEqual(tabsIn("look", {}).map(s => s.key), ["look", "appearance", "motion", "sync"])
    assert.deepEqual(tabsIn("nope", {}), [])
})
