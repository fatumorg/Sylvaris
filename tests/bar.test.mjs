import { test } from "node:test"
import assert from "node:assert/strict"
import { unused, shift, validateBar, validateDeck, deckItems, nextWindow, togglePin, magnify, DEFAULT_BAR, vertical, drawerArrow, placeCorner, deckHidden, screenBusy, workspaceLook, WORKSPACE_ICONS, workspaceApps, workspaceTicks, middleSlot } from "../shell/lib/bar.mjs"

test("validateBar keeps known modules once and falls back per side", () => {
    const b = validateBar({ left: ["clock", "nope", "clock", "pad"], floating: false })
    assert.deepEqual(b.left, ["clock", "pad"])
    assert.deepEqual(b.center, [])
    assert.deepEqual(b.right, DEFAULT_BAR.right)
    assert.equal(b.floating, false)
    assert.equal(b.enabled, true)
    assert.deepEqual(validateBar({}).left, DEFAULT_BAR.left)
})

test("validateDeck is off by default and cleans its values", () => {
    const d = validateDeck({ pinned: ["firefox", "", "firefox", 3, "kitty"], pad: "middle", size: 400 })
    assert.equal(d.enabled, false)
    assert.deepEqual(d.pinned, ["firefox", "kitty"])
    assert.equal(d.pad, "start")
    assert.equal(d.size, 56)
    assert.equal(validateDeck({ enabled: true }).enabled, true)
})

test("deckItems puts pinned apps first and groups running windows by app", () => {
    const windows = [{ appId: "kitty" }, { appId: "org.mozilla.firefox" }, { appId: "kitty" }, { appId: "spotify" }]
    const entryOf = a => ({ "org.mozilla.firefox": "firefox", kitty: "kitty" })[a] || ""
    assert.deepEqual(deckItems(["firefox", "nemo"], windows, entryOf), [
        { id: "firefox", pinned: true, windows: [1] },
        { id: "nemo", pinned: true, windows: [] },
        { id: "kitty", pinned: false, windows: [0, 2] },
        { id: "spotify", pinned: false, windows: [3] }
    ])
})

test("nextWindow cycles through an app's windows starting after the focused one", () => {
    const w = [{ activated: false }, { activated: true }, { activated: false }]
    assert.equal(nextWindow([0, 1, 2], w), 2)
    assert.equal(nextWindow([0, 2], w), 0)
    assert.equal(nextWindow([], w), -1)
})

test("togglePin adds and removes", () => {
    assert.deepEqual(togglePin(["a"], "b"), ["a", "b"])
    assert.deepEqual(togglePin(["a", "b"], "a"), ["b"])
})

test("magnify peaks under the pointer and fades to 1", () => {
    assert.equal(magnify(0, 150), 1.45)
    assert.equal(magnify(150, 150), 1)
    assert.ok(magnify(75, 150) > 1 && magnify(75, 150) < 1.45)
})

test("unused lists modules on no side, shift moves within bounds", () => {
    assert.deepEqual(unused({ left: ["pad", "clock"], center: [], right: ["workspaces", "window", "media", "tray", "audio", "network", "bluetooth", "battery"] }), ["notifications", "center", "power", "diver", "temp"])
    assert.deepEqual(shift(["a", "b", "c"], 0, 1), ["b", "a", "c"])
    assert.deepEqual(shift(["a", "b", "c"], 2, 1), ["a", "b", "c"])
    assert.deepEqual(shift(["a", "b", "c"], 2, -2), ["c", "a", "b"])
})

test("bar position, style and drawer direction", () => {
    assert.equal(validateBar({ position: "left" }).position, "left")
    assert.equal(validateBar({ position: "middle" }).position, "top")
    assert.equal(validateBar({ style: "slab" }).style, "slab")
    assert.equal(validateBar({}).style, "islands")
    assert.equal(validateBar({ style: "float" }).style, "float")
    assert.equal(validateBar({ style: "minimal" }).style, "minimal")
    assert.equal(validateBar({}).workspaceStyle, "pills")
    assert.equal(validateBar({ workspaceStyle: "dots" }).workspaceStyle, "dots")
    assert.equal(validateBar({ workspaceStyle: "icons" }).workspaceStyle, "icons")
    assert.equal(validateBar({ workspaceStyle: "bubbles" }).workspaceStyle, "pills")
    assert.equal(vertical("right"), true)
    assert.equal(vertical("bottom"), false)
    assert.deepEqual(["top", "bottom", "left", "right"].map(drawerArrow), ["down", "up", "right", "left"])
})

test("placeCorner opens popups next to the bar wherever it sits", () => {
    assert.equal(placeCorner("top-left", "top"), "top-left")
    assert.equal(placeCorner("top-center", "bottom"), "bottom-center")
    assert.equal(placeCorner("top-right", "bottom"), "bottom-right")
    assert.equal(placeCorner("top-left", "left"), "top-left")
    assert.equal(placeCorner("top-center", "left"), "center-left")
    assert.equal(placeCorner("top-right", "left"), "bottom-left")
    assert.equal(placeCorner("top-left", "right"), "top-right")
    assert.equal(placeCorner("top-center", "right"), "center-right")
    assert.equal(placeCorner("top-right", "right"), "bottom-right")
    assert.equal(placeCorner("center", "bottom"), "center")
    assert.equal(placeCorner("nonsense", "top"), "top-center")
})

test("deck effect replaces the old magnify flag", () => {
    assert.equal(validateDeck({}).effect, "bloom")
    assert.equal(validateDeck({ magnify: true }).effect, "magnify")
    assert.equal(validateDeck({ effect: "none", magnify: true }).effect, "none")
    assert.equal(validateDeck({}).reserve, true)
    assert.equal(validateDeck({ reserve: false }).reserve, false)
    assert.equal(validateDeck({ power: "end" }).power, "end")
})

test("validateDeck turns the old autohide switch into a hide mode and keeps the peek pill in range", () => {
    assert.equal(validateDeck({}).hide, "never")
    assert.equal(validateDeck({ autohide: true }).hide, "always")
    assert.equal(validateDeck({ hide: "windows", autohide: true }).hide, "windows")
    assert.equal(validateDeck({ hide: "sometimes" }).hide, "never")
    assert.equal(validateDeck({}).peek, true)
    assert.equal(validateDeck({ peek: false }).peek, false)
    assert.equal(validateDeck({}).peekSize, 4)
    assert.equal(validateDeck({ peekSize: 40 }).peekSize, 4)
    assert.equal(validateDeck({ peekSize: 8 }).peekSize, 8)
})

test("deckHidden hides for always, for windows only when the screen is busy, and never while in use", () => {
    const idle = { hovering: false, menu: false, holding: false, busy: false }
    assert.equal(deckHidden("never", Object.assign({}, idle, { busy: true })), false)
    assert.equal(deckHidden("always", idle), true)
    assert.equal(deckHidden("windows", idle), false)
    assert.equal(deckHidden("windows", Object.assign({}, idle, { busy: true })), true)
    assert.equal(deckHidden("always", Object.assign({}, idle, { hovering: true })), false)
    assert.equal(deckHidden("windows", Object.assign({}, idle, { busy: true, menu: true })), false)
    assert.equal(deckHidden("always", Object.assign({}, idle, { holding: true })), false)
})

test("screenBusy uses the visible workspace's window count and falls back to open windows when it is unknown", () => {
    const ws = [{ output: "A", active: true, windows: 2 }, { output: "A", active: false, windows: 0 }, { output: "B", active: true, windows: 0 }]
    assert.equal(screenBusy(ws, [], "A"), true)
    assert.equal(screenBusy(ws, [{ minimized: false }], "B"), false)
    const sway = [{ output: "A", active: true, windows: -1 }]
    assert.equal(screenBusy(sway, [], "A"), false)
    assert.equal(screenBusy(sway, [{ minimized: true }], "A"), false)
    assert.equal(screenBusy(sway, [{ minimized: false }], "A"), true)
    assert.equal(screenBusy([], [{ minimized: false }], "A"), false)
})

test("workspaceLook picks numbers, dots or a glyph set, and auto follows the theme", () => {
    assert.deepEqual(workspaceLook("numbers", "paw"), { mode: "numbers", glyph: "" })
    assert.deepEqual(workspaceLook("dots", ""), { mode: "dots", glyph: "" })
    assert.deepEqual(workspaceLook("heart", ""), { mode: "glyph", glyph: WORKSPACE_ICONS.heart })
    assert.deepEqual(workspaceLook("auto", "paw"), { mode: "glyph", glyph: WORKSPACE_ICONS.paw })
    assert.deepEqual(workspaceLook("auto", "unknown"), { mode: "numbers", glyph: "" })
    assert.equal(validateBar({ workspaceIcons: "paw" }).workspaceIcons, "paw")
    assert.equal(validateBar({ workspaceIcons: "rocket" }).workspaceIcons, "auto")
})

test("workspace pills show each app once and at most three ticks", () => {
    assert.deepEqual(workspaceApps(["kitty", "firefox", "kitty", "", "nemo", "steam"], 3), { shown: ["kitty", "firefox", "nemo"], more: 1 })
    assert.deepEqual(workspaceApps(undefined, 3), { shown: [], more: 0 })
    assert.equal(workspaceTicks(-1), 0)
    assert.equal(workspaceTicks(7), 3)
})

test("middleSlot centres the middle group, slides it into the free gap, or gives up", () => {
    assert.equal(middleSlot(1000, 200, 100, 200, 12), 450)
    assert.equal(middleSlot(1000, 500, 100, 200, 12), 512)
    assert.equal(middleSlot(1000, 200, 100, 500, 12), 388)
    assert.equal(middleSlot(1000, 450, 100, 450, 12), -1)
    assert.equal(middleSlot(1000, 0, 100, 0, 12), 450)
})
