import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync, statSync } from "node:fs"
import { join } from "node:path"
import { ticksLit, tickValue } from "../shell/lib/controls.mjs"
import { CONTROL_CHOICES } from "../shell/lib/look.mjs"

const ROOT = new URL("../shell/", import.meta.url).pathname

test("ticks light the nearest segment and clicks reach both ends", () => {
    assert.equal(ticksLit(0.62, 12), 7); assert.equal(ticksLit(0, 12), 0); assert.equal(ticksLit(1.4, 12), 12)
    assert.equal(tickValue(0, 12), 0); assert.equal(tickValue(11, 12), 1)
})

test("every shared control reads its style from the tokens", () => {
    for (const [file, token] of [["Toggle", "toggleStyle"], ["Slider", "sliderStyle"], ["Segmented", "segmentedStyle"], ["RowButton", "buttonStyle"], ["Glyph", "iconStyle"], ["Divider", "dividerStyle"], ["Caption", "labelCase"]])
        assert.ok(readFileSync(join(ROOT, "components/" + file + ".qml"), "utf8").includes("Tokens." + token), file)
})

test("each anatomy name in CONTROL_CHOICES is drawn by its component", () => {
    for (const [file, key] of [["Toggle", "toggle"], ["Slider", "slider"], ["Segmented", "segmented"], ["RowButton", "button"], ["Glyph", "icon"], ["Divider", "divider"]])
        for (const v of CONTROL_CHOICES[key]) assert.ok(readFileSync(join(ROOT, "components/" + file + ".qml"), "utf8").includes("\"" + v + "\""), file + " " + v)
})

function qmlFilesOutside(skip, dir = "") {
    return readdirSync(join(ROOT, dir)).flatMap(name => {
        const rel = dir === "" ? name : dir + "/" + name
        if (statSync(join(ROOT, rel)).isDirectory())
            return rel === skip ? [] : qmlFilesOutside(skip, rel)
        return rel.endsWith(".qml") ? [rel] : []
    })
}

test("panels draw separators with Divider", () => {
    const ALLOW = {
        "files/Entry.qml": ["height: 1"],
        "services/Awake.qml": ["implicitHeight: 1"],
        "clock/SylClock.qml": ["height: 1"],
        "widgets/types/SkyWidget.qml": ["height: 1"],
        "media/SylMedia.qml": ["height: 1"],
        "deck/SylDeck.qml": ["height: 1"]
    }
    const offenders = qmlFilesOutside("components").flatMap(f => readFileSync(join(ROOT, f), "utf8").split("\n").map((l, i) => [f, i + 1, l.trim()]).filter(([f, , l]) => /^(implicitH|h)eight: 1$/.test(l) && !(ALLOW[f] || []).includes(l)))
    assert.deepEqual(offenders, [])
})
