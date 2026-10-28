import { test } from "node:test"
import assert from "node:assert/strict"
import { pushUndo, popUndo } from "../shell/lib/undo.mjs"

test("pushUndo keeps the last twenty", () => {
    let s = []
    for (let i = 0; i < 25; i++)
        s = pushUndo(s, { key: "k" + i, before: i })
    assert.equal(s.length, 20)
    assert.equal(s[0].key, "k5")
    assert.equal(s[19].key, "k24")
    assert.equal(pushUndo([], { key: "a" }, 1).length, 1)
})

test("popUndo gives the newest entry, or null when empty", () => {
    const r = popUndo(pushUndo(pushUndo([], { key: "a", before: 1 }), { key: "b", before: 2 }))
    assert.deepEqual(r.entry, { key: "b", before: 2 })
    assert.equal(r.stack.length, 1)
    assert.equal(popUndo([]).entry, null)
    assert.deepEqual(popUndo([]).stack, [])
})
