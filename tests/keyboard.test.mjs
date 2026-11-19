import { test } from "node:test"
import assert from "node:assert/strict"
import { LAYOUTS, PAGES, validLayout, rowsFor, symFor, labelFor, move, textFor, DEFAULT_KEYBOARD, validateKeyboard } from "../shell/lib/keyboard.mjs"
import { DEFAULT_SETTINGS, validateSettings } from "../shell/lib/settings.mjs"

const find = (rows, label) => {
    for (let r = 0; r < rows.length; r++) {
        const c = rows[r].findIndex(k => k.label === label)
        if (c >= 0)
            return rows[r][c]
    }
    return null
}

test("only known layouts are valid", () => {
    assert.deepEqual(Object.keys(LAYOUTS).sort(), ["pl", "us"])
    assert.equal(validLayout("pl"), true)
    assert.equal(validLayout("xx"), false)
    assert.equal(validLayout(7), false)
    assert.deepEqual(PAGES, ["letters", "symbols"])
})

test("polish adds altgr letters on the home row", () => {
    const rows = rowsFor("pl", "letters")
    const a = rows[2].find(k => k.label === "a")
    assert.equal(symFor(a, false, true), "aogonek")
    assert.equal(symFor(a, true, true), "Aogonek")
    assert.equal(labelFor(a, false, true), "ą")
    assert.equal(symFor(find(rows, "l"), false, true), "lstroke")
    assert.equal(symFor(find(rows, "x"), false, true), "zacute")
    assert.equal(symFor(find(rows, "z"), false, true), "zabovedot")
})

test("us keys send their plain and shifted keysyms", () => {
    const rows = rowsFor("us", "letters")
    assert.equal(symFor(find(rows, "a"), false, false), "a")
    assert.equal(symFor(find(rows, "a"), true, false), "A")
    assert.equal(symFor(find(rows, "1"), true, false), "exclam")
    assert.equal(symFor(find(rows, "a"), false, true), "a")
    assert.equal(find(rows, "⌫").action, "backspace")
    assert.equal(rowsFor("xx", "letters"), rows)
})

test("every key has a keysym or an action and a width", () => {
    for (const id of Object.keys(LAYOUTS))
        for (const page of PAGES)
            for (const row of rowsFor(id, page))
                for (const k of row) {
                    assert.ok(typeof k.label === "string" && k.label !== "")
                    assert.ok((typeof k.sym === "string" && k.sym !== "") || typeof k.action === "string", id + " " + k.label)
                    assert.ok(k.width > 0)
                }
})

test("moving right from the last key wraps to the row start", () => {
    const rows = rowsFor("us", "letters")
    assert.deepEqual(move(rows, 1, rows[1].length - 1, "right"), { r: 1, c: 0 })
    assert.deepEqual(move(rows, 1, 0, "left"), { r: 1, c: rows[1].length - 1 })
})

test("moving up from the top row wraps to the bottom row", () => {
    const rows = rowsFor("us", "letters")
    assert.equal(move(rows, 0, 0, "up").r, rows.length - 1)
    assert.equal(move(rows, rows.length - 1, 0, "down").r, 0)
})

test("moving onto a shorter row picks the nearest key centre", () => {
    const rows = [
        [{ label: "a", sym: "a", width: 1 }, { label: "b", sym: "b", width: 1 }, { label: "c", sym: "c", width: 1 }, { label: "d", sym: "d", width: 1 }],
        [{ label: " ", sym: "space", width: 3 }, { label: "e", sym: "e", width: 1 }]
    ]
    assert.deepEqual(move(rows, 0, 1, "down"), { r: 1, c: 0 })
    assert.deepEqual(move(rows, 0, 3, "down"), { r: 1, c: 1 })
    assert.deepEqual(move(rows, 1, 1, "up"), { r: 0, c: 3 })
    assert.deepEqual(move(rows, 0, 0, "nowhere"), { r: 0, c: 0 })
})

test("keyboard settings fall back to defaults when invalid", () => {
    assert.deepEqual(DEFAULT_KEYBOARD, { layout: "us", size: 1, gamepad: true, combo: true })
    assert.deepEqual(validateKeyboard({ layout: "pl", size: 1.4, gamepad: false, combo: false }), { layout: "pl", size: 1.4, gamepad: false, combo: false })
    assert.deepEqual(validateKeyboard({ layout: "de", size: 2, gamepad: "yes", combo: 1 }), DEFAULT_KEYBOARD)
    assert.equal(validateKeyboard({ size: 0.5 }).size, 1)
    assert.equal(validateKeyboard(null).layout, "us")
    assert.equal(validateKeyboard({ extra: 3 }).extra, 3)
})

test("settings carry and repair the keyboard section", () => {
    assert.deepEqual(DEFAULT_SETTINGS.keyboard, DEFAULT_KEYBOARD)
    assert.equal(validateSettings({ keyboard: { layout: "xx" } }).keyboard.layout, "us")
})

test("only text keys put text in the focus mode preview", () => {
    const rows = rowsFor("pl", "letters")
    assert.equal(textFor(find(rows, "a"), true, false), "A")
    assert.equal(textFor(find(rows, "e"), false, true), "ę")
    assert.equal(textFor(find(rows, "1"), true, false), "!")
    assert.equal(textFor(find(rows, "Space"), false, false), " ")
    for (const label of ["Esc", "❖", "Tab", "Enter", "⌫", "←", "↑", "Caps", "⇧", "123", "AltGr"])
        assert.equal(textFor(find(rows, label), false, false), "", label)
    assert.equal(textFor(null, false, false), "")
    assert.equal(textFor(find(rowsFor("us", "symbols"), "{"), false, false), "{")
})
