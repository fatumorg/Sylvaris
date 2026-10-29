import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
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
