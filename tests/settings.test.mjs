import { test } from "node:test"
import { readFileSync, readdirSync } from "node:fs"
import assert from "node:assert/strict"
import {
    CORNERS, DEFAULT_CONFIG, DEFAULT_SETTINGS, parseJson, expandHome, deepMerge, migrate,
    validateConfig, validateSettings, merge, getPath, setPath, serialize, DEFAULT_GLASS, resolveGlass, settingsLayer, effectiveSettings,
    PARTS, OPT_IN, SERVICE_DEPS, liveParts, screenSettings, screenKey, liveServices, CENTER_TILES, unsetPath, isModified
} from "../shell/lib/settings.mjs"
import { TYPES } from "../shell/lib/widgets.mjs"

test("parseJson treats empty text as an empty object", () => {
    assert.deepEqual(parseJson(""), { ok: true, value: {} })
    assert.deepEqual(parseJson("  \n"), { ok: true, value: {} })
    assert.deepEqual(parseJson(null), { ok: true, value: {} })
})

test("parseJson rejects invalid JSON and non-objects", () => {
    assert.equal(parseJson("{nope").ok, false)
    assert.equal(parseJson("[1,2]").ok, false)
    assert.equal(parseJson("42").ok, false)
    assert.equal(typeof parseJson("{nope").error, "string")
})

test("parseJson returns objects", () => {
    assert.deepEqual(parseJson('{"a":1}'), { ok: true, value: { a: 1 } })
})

test("expandHome expands a leading tilde only", () => {
    assert.equal(expandHome("~/x/y", "/home/u"), "/home/u/x/y")
    assert.equal(expandHome("~", "/home/u"), "/home/u")
    assert.equal(expandHome("/abs/~/x", "/home/u"), "/abs/~/x")
    assert.equal(expandHome("", "/home/u"), "")
})

test("deepMerge merges objects, replaces arrays and does not mutate", () => {
    const base = { a: { b: 1, c: 2 }, list: [1, 2], keep: true }
    const over = { a: { c: 3 }, list: [9] }
    const out = deepMerge(base, over)
    assert.deepEqual(out, { a: { b: 1, c: 3 }, list: [9], keep: true })
    assert.deepEqual(base, { a: { b: 1, c: 2 }, list: [1, 2], keep: true })
    assert.deepEqual(over, { a: { c: 3 }, list: [9] })
})

test("migrate adds version 1 and keeps newer versions", () => {
    assert.equal(migrate({}).version, 1)
    assert.equal(migrate({ version: 2 }).version, 2)
    assert.equal(migrate(null).version, 1)
})

test("validateConfig fills defaults and keeps unknown keys", () => {
    const v = validateConfig({ themeHook: "hook", extra: { x: 1 }, terminal: 5 })
    assert.equal(v.themeHook, "hook")
    assert.equal(v.terminal, DEFAULT_CONFIG.terminal)
    assert.equal(v.themesDir, DEFAULT_CONFIG.themesDir)
    assert.deepEqual(v.extra, { x: 1 })
    assert.equal(v.version, 1)
})

test("validateConfig keeps valid toggles, drops invalid ones and duplicates", () => {
    const v = validateConfig({
        toggles: [
            { id: "performance", label: "Performance", on: "a", off: "b" },
            { id: "Bad Id", label: "x" },
            { id: "nolabel" },
            { id: "performance", label: "Duplicate" },
            "junk"
        ]
    })
    assert.equal(v.toggles.length, 1)
    assert.deepEqual(v.toggles[0], { id: "performance", label: "Performance", icon: "\u{F0521}", on: "a", off: "b", status: "" })
})

test("validateConfig replaces non-array toggles and commands", () => {
    const v = validateConfig({ toggles: "x", commands: {} })
    assert.deepEqual(v.toggles, [])
    assert.deepEqual(v.commands, [])
})

test("validateSettings fixes invalid values field by field", () => {
    const v = validateSettings({
        cc: { corner: "bottom", other: 1 },
        nightLight: { enabled: "yes", temperature: 50000 },
        displays: { layouts: [] },
        toggleState: { a: true, b: "no" },
        hotspot: { ssid: "x".repeat(33), band: "z" },
        unknown: 7
    })
    assert.deepEqual(v.center, { corner: "top-right", other: 1, hidden: [], extra: [], volume: true, media: true })
    assert.deepEqual(v.nightLight, { enabled: false, temperature: 4000 })
    assert.deepEqual(v.displays, { layouts: {}, virtual: { enabled: false, width: 2388, height: 1668 } })
    assert.deepEqual(v.toggleState, { a: true })
    assert.deepEqual(v.hotspot, { ssid: "Sylvaris", band: "bg" })
    assert.equal(v.unknown, 7)
})

test("validateSettings keeps valid values", () => {
    const v = validateSettings({
        center: { corner: "top-left" },
        nightLight: { enabled: true, temperature: 3500 },
        hotspot: { ssid: "Mine", band: "a" }
    })
    assert.equal(v.center.corner, "top-left")
    assert.deepEqual(v.nightLight, { enabled: true, temperature: 3500 })
    assert.deepEqual(v.hotspot, { ssid: "Mine", band: "a" })
    assert.ok(CORNERS.includes("top-center"))
})

test("validateSettings of nothing equals the defaults", () => {
    assert.deepEqual(validateSettings({}), JSON.parse(JSON.stringify(DEFAULT_SETTINGS)))
})

test("merge lets settings win over config on shared keys", () => {
    const out = merge({ extra: "config", themeHook: "h" }, { extra: "settings" })
    assert.equal(out.extra, "settings")
    assert.equal(out.themeHook, "h")
    assert.equal(out.center.corner, "top-right")
})

test("getPath and setPath work on nested keys without mutating", () => {
    const obj = { a: { b: 1 } }
    const next = setPath(obj, "a.c.d", 5)
    assert.equal(getPath(next, "a.c.d"), 5)
    assert.equal(getPath(next, "a.b"), 1)
    assert.equal(getPath(obj, "a.c"), undefined)
    assert.equal(getPath(obj, "x.y"), undefined)
    const layouts = setPath({}, "displays.layouts.DP-1+HDMI-A-1", { x: 1 })
    assert.deepEqual(layouts, { displays: { layouts: { "DP-1+HDMI-A-1": { x: 1 } } } })
})

test("getPath and setPath refuse keys that reach the prototype", () => {
    for (const key of ["__proto__.polluted", "a.constructor.prototype.polluted", "a.__proto__"])
        assert.throws(() => setPath({ a: {} }, key, true))
    assert.equal({}.polluted, undefined)
    assert.equal(getPath({ a: {} }, "a.toString"), undefined)
    assert.equal(getPath({ a: {} }, "__proto__"), undefined)
})

test("serialize produces parseable JSON with a trailing newline", () => {
    const text = serialize({ a: 1 })
    assert.ok(text.endsWith("\n"))
    assert.deepEqual(JSON.parse(text), { a: 1 })
})

test("resolveGlass returns the defaults without input", () => {
    const r = resolveGlass(undefined, undefined)
    assert.deepEqual(r.values, DEFAULT_GLASS)
    assert.deepEqual(r.errors, [])
    assert.deepEqual(DEFAULT_GLASS, { enabled: true, opacity: 0.55, layerOpacity: 0.35, tint: 0.14, sheen: 0.35, flow: 1, rim: 0.5 })
})

test("resolveGlass lets settings.json override config.json", () => {
    const r = resolveGlass({ opacity: 0.4, rim: 0.2 }, { opacity: 0.7, enabled: false })
    assert.equal(r.values.opacity, 0.7)
    assert.equal(r.values.rim, 0.2)
    assert.equal(r.values.enabled, false)
    assert.deepEqual(r.errors, [])
})

test("resolveGlass quietly drops the retired grain key", () => {
    const r = resolveGlass({ grain: 0.035 }, { grain: 0.028 })
    assert.deepEqual(r.values, DEFAULT_GLASS)
    assert.deepEqual(r.errors, [])
})

test("resolveGlass keeps the lower layer for invalid values and reports them", () => {
    const r = resolveGlass({ opacity: 0.4 }, { opacity: 55, flow: "fast", enabled: "no", shine: 1 })
    assert.equal(r.values.opacity, 0.4)
    assert.equal(r.values.flow, 1)
    assert.equal(r.values.enabled, true)
    assert.deepEqual(r.errors, [
        "settings.json glass.opacity must be a number from 0 to 1",
        "settings.json glass.flow must be a number from 0 to 3",
        "settings.json glass.enabled must be true or false",
        "settings.json glass.shine is not a glass key"
    ])
})

test("resolveGlass rejects a glass block that is not an object", () => {
    const r = resolveGlass([1], "x")
    assert.deepEqual(r.values, DEFAULT_GLASS)
    assert.deepEqual(r.errors, ["config.json glass must be an object", "settings.json glass must be an object"])
})

test("validateSettings keeps the glass block for resolveGlass", () => {
    assert.deepEqual(validateSettings({ glass: { opacity: 0.3 } }).glass, { opacity: 0.3 })
})

test("notification settings and config are validated field by field", () => {
    const v = validateSettings({ notifications: { dnd: "yes", timeout: 50, corner: "top-left" } })
    assert.deepEqual(v.notifications, { dnd: false, timeout: 5000, corner: "top-left" })
    const c = validateConfig({ notifications: { server: false, history: 5000 } })
    assert.deepEqual(c.notifications, { server: false, history: 100 })
    assert.deepEqual(validateConfig({}).notifications, { server: true, history: 100 })
})

test("launcher grid size stays within bounds", () => {
    assert.deepEqual(validateSettings({ pad: { columns: 40, rows: 3 } }).pad, { columns: 7, rows: 3, mode: "launchpad" })
    assert.equal(validateSettings({ pad: { mode: "list" } }).pad.mode, "list")
    assert.equal(validateSettings({ pad: { mode: "rofi" } }).pad.mode, "launchpad")
})

test("config.json can hold settings defaults that settings.json overrides", () => {
    const config = { themeHook: "h", bar: { floating: false }, deck: { enabled: true, size: 64 }, center: { corner: "top-left" } }
    assert.deepEqual(Object.keys(settingsLayer(config)).sort(), ["bar", "center", "deck"])
    const e = effectiveSettings(config, { deck: { size: 48 } })
    assert.equal(e.bar.floating, false)
    assert.equal(e.deck.enabled, true)
    assert.equal(e.deck.size, 48)
    assert.equal(e.center.corner, "top-left")
    assert.equal(effectiveSettings(config, { center: { corner: "bogus" } }).center.corner, "top-right")
    assert.deepEqual(effectiveSettings({}, {}), validateSettings({}))
})

test("parts default to every part but the opt-in ones and keep only boolean false", () => {
    assert.deepEqual(Object.keys(DEFAULT_SETTINGS.parts), Object.keys(PARTS))
    assert.ok(Object.entries(DEFAULT_SETTINGS.parts).every(([k, v]) => v === !OPT_IN.includes(k)))
    assert.equal(liveParts(undefined).includes("island"), false)
    assert.equal(validateSettings({ parts: { island: "yes" } }).parts.island, false)
    assert.equal(liveParts(validateSettings({ parts: { island: true } }).parts).includes("island"), true)
    const v = validateSettings({ parts: { pad: false, center: "no", nope: false } })
    assert.equal(v.parts.pad, false)
    assert.equal(v.parts.center, true)
    assert.equal("nope" in v.parts, false)
    assert.equal(effectiveSettings({ parts: { pad: false } }, { parts: { pad: true } }).parts.pad, true)
    assert.equal(effectiveSettings({ parts: { pad: false } }, {}).parts.pad, false)
})

const NONE = Object.fromEntries(Object.keys(PARTS).map(k => [k, false]))
const alone = name => liveServices({ ...NONE, [name]: true })

test("an excluded part contributes nothing to the parts and services shell.qml boots", () => {
    for (const name of Object.keys(PARTS)) {
        const flags = validateSettings({ parts: { [name]: false } }).parts
        assert.equal(liveParts(flags).includes(name), false)
        const others = new Set(Object.keys(PARTS).filter(n => n !== name).flatMap(alone))
        assert.deepEqual(new Set(liveServices(flags)), others, name)
    }
    assert.deepEqual(liveParts(NONE), [])
    assert.deepEqual(liveServices(NONE), [])
    assert.ok(alone("center").includes("Displays"))
    assert.ok(alone("bar").includes("Equalizer"))
    assert.equal(liveServices({ ...DEFAULT_SETTINGS.parts, center: false }).includes("Hotspot"), false)
})

test("widgets start the services their items need, and only while the part is on", () => {
    assert.ok(liveServices(NONE, {}, { items: [] }).length === 0)
    assert.deepEqual(liveServices({ ...NONE, widgets: true }, {}, { items: [] }), [])
    const weather = liveServices({ ...NONE, widgets: true }, {}, { items: [{ type: "weather" }] })
    assert.ok(weather.includes("Weather") && weather.includes("Sky"))
    assert.equal(liveServices({ ...NONE, widgets: false }, {}, { items: [{ type: "weather" }] }).includes("Weather"), false)
    assert.equal(liveServices({ ...NONE, widgets: true }, {}, { items: [{ type: "temp" }] }).includes("Temps"), false)
})

test("shell.qml loads every part only through its parts flag", () => {
    const qml = readFileSync(new URL("../shell/shell.qml", import.meta.url), "utf8")
    for (const name of Object.keys(PARTS))
        assert.match(qml, new RegExp("LazyLoader \\{\\n(        id: \\w+\\n)?        active: root\\.on\\(\"" + name + "\"\\)"), name)
    const bootLine = qml.split("\n").find(l => l.includes("readonly property var boot:"))
    for (const svc of Object.keys(SERVICE_DEPS).concat(...Object.values(PARTS)))
        assert.equal(new RegExp("\\b" + svc + "\\b").test(bootLine), false, svc + " is booted unconditionally")
})

test("PARTS lists every service a part references", () => {
    const root = new URL("../shell/", import.meta.url)
    const core = ["Config", "Settings", "Look", "Ipc", "Demo", "Theme", "Resin", "Compositor", "Keybinds", "Privacy"]
    const services = readdirSync(new URL("services/", root)).map(f => f.replace(".qml", "")).filter(n => !core.includes(n)).concat("Diver")
    const dirOf = name => name === "diver" || name === "fatest" || name === "rgb" ? "plugins/" + name : name
    const refs = dir => {
        const found = new Set()
        for (const f of readdirSync(new URL(dir + "/", root), { recursive: true }).filter(f => f.endsWith(".qml") && (dir !== "plugins" || !f.includes("/")))) {
            const text = readFileSync(new URL(dir + "/" + f, root), "utf8")
            for (const svc of services.concat("DayAgenda"))
                if (new RegExp("\\b" + svc + "[.{]").test(text))
                    found.add(svc)
        }
        return found
    }
    const agenda = refs("components").has("Diver")
    for (const name of Object.keys(PARTS)) {
        const used = refs(dirOf(name))
        if (used.has("DayAgenda") && agenda)
            used.add("Diver")
        used.delete("DayAgenda")
        const listed = name === "widgets" ? liveServices({ ...NONE, widgets: true }, { enabled: { diver: true, temp: true } }, { items: Object.keys(TYPES).map(type => ({ type })) }) : alone(name)
        for (const svc of used)
            assert.ok(listed.includes(svc), name + " uses " + svc)
    }
})

test("motion.reveal picks how full-screen backgrounds open", () => {
    assert.equal(validateSettings({}).motion.reveal, "edges")
    assert.equal(validateSettings({ motion: { reveal: "center" } }).motion.reveal, "center")
    assert.equal(validateSettings({ motion: { reveal: "fade" } }).motion.reveal, "fade")
    assert.equal(validateSettings({ motion: { reveal: "spin" } }).motion.reveal, "edges")
})

test("switcher shows previews and titles unless turned off, and is a part", () => {
    assert.deepEqual(validateSettings({}).switcher, { previews: true, titles: true })
    assert.deepEqual(validateSettings({ switcher: { previews: false, titles: "no" } }).switcher, { previews: false, titles: true })
    assert.deepEqual(PARTS.switcher, ["Apps"])
    assert.equal(validateSettings({ parts: { switcher: false } }).parts.switcher, false)
})

test("the diver part and its service only run while the Diver plugin is on", () => {
    const off = { enabled: {} }
    const on = { enabled: { diver: true } }
    assert.equal(liveParts(DEFAULT_SETTINGS.parts, off).includes("diver"), false)
    assert.equal(liveParts(DEFAULT_SETTINGS.parts, on).includes("diver"), true)
    assert.equal(liveParts({ ...DEFAULT_SETTINGS.parts, diver: false }, on).includes("diver"), false)
    assert.equal(liveServices(DEFAULT_SETTINGS.parts, off).includes("Diver"), false)
    assert.equal(liveServices(DEFAULT_SETTINGS.parts, on).includes("Diver"), true)
    assert.equal(liveParts(DEFAULT_SETTINGS.parts, off).includes("clock"), true)
})

test("center settings keep known tiles and section switches", () => {
    const v = validateSettings({ center: { hidden: ["wifi", "toggle:performance", "wifi", "Toggle:Bad", "nope", 3], volume: false, media: "no" } })
    assert.deepEqual(v.center.hidden, ["wifi", "toggle:performance"])
    assert.equal(v.center.volume, false)
    assert.equal(v.center.media, true)
    assert.deepEqual(validateSettings({ center: { hidden: "wifi" } }).center.hidden, [])
    assert.deepEqual(CENTER_TILES, ["wifi", "bluetooth", "night", "dnd", "hotspot"])
})

test("placement keeps each panel's spot and falls back per panel", () => {
    const d = validateSettings({}).placement
    assert.deepEqual(d, { media: "auto", clip: "top-center", capture: "top-center", access: "top-center", diver: "center", fatest: "top-right", rgb: "top-right" })
    const v = validateSettings({ placement: { media: "top-left", clip: "center", capture: "nope", access: "auto", diver: "top-right", extra: 1 } }).placement
    assert.equal(v.media, "top-left")
    assert.equal(v.clip, "center")
    assert.equal(v.capture, "top-center")
    assert.equal(v.access, "top-center")
    assert.equal(v.diver, "top-right")
    assert.equal(v.extra, 1)
    assert.deepEqual(validateSettings({ placement: "x" }).placement, d)
})

test("screens keep only per-screen overrides the validator accepts", () => {
    const v = validateSettings({ screens: { "DP-6": { bar: { position: "left" }, deck: { pinned: ["x"], size: 64 }, island: { position: "bottom-left", media: false }, clock: { corner: "nope" }, performance: true }, "HDMI-A-1": "x" } })
    assert.deepEqual(v.screens, { "DP-6": { bar: { position: "left" }, deck: { size: 64 }, island: { position: "bottom-left" } } })
    assert.deepEqual(validateSettings({}).screens, {})
    assert.deepEqual(validateSettings({ screens: [] }).screens, {})
    assert.deepEqual(validateSettings({ screens: { "DP-6": {} } }).screens, { "DP-6": {} })
})

test("screenSettings lays a screen's overrides over the shared settings", () => {
    const v = validateSettings({ bar: { floating: false }, screens: { "DP-6": { bar: { position: "left" }, placement: { clip: "center" } } } })
    const s = screenSettings(v, "DP-6")
    assert.equal(s.bar.position, "left")
    assert.equal(s.bar.floating, false)
    assert.equal(s.placement.clip, "center")
    assert.equal(screenSettings(v, "DP-5").bar.position, "top")
    assert.equal(screenSettings(v, "").bar.position, "top")
    assert.equal(screenSettings(v, "DP-5"), v)
})

test("screenKey tells which settings can differ per screen", () => {
    assert.equal(screenKey("bar.position"), true)
    assert.equal(screenKey("bar"), true)
    assert.equal(screenKey("deck.size"), true)
    assert.equal(screenKey("deck.pinned"), false)
    assert.equal(screenKey("island.position"), true)
    assert.equal(screenKey("island.media"), false)
    assert.equal(screenKey("notifications.corner"), true)
    assert.equal(screenKey("notifications.dnd"), false)
    assert.equal(screenKey("parts.bar"), false)
})

test("deepMerge ignores __proto__, constructor and prototype keys", () => {
    const r = deepMerge({ bar: { position: "top" } }, JSON.parse("{\"__proto__\":{\"polluted\":1},\"bar\":{\"__proto__\":{\"x\":2},\"constructor\":{\"y\":3}}}"))
    assert.equal(Object.getPrototypeOf(r), Object.prototype)
    assert.equal(Object.getPrototypeOf(r.bar), Object.prototype)
    assert.equal(r.bar.x, undefined)
    assert.equal(Object.prototype.hasOwnProperty.call(r.bar, "constructor"), false)
    assert.deepEqual(r, { bar: { position: "top" } })
})

test("performance is off, auto or on; old true means on and old false means auto", () => {
    assert.equal(DEFAULT_SETTINGS.performance, "auto")
    assert.equal(validateSettings({}).performance, "auto")
    assert.equal(validateSettings({ performance: true }).performance, "on")
    assert.equal(validateSettings({ performance: false }).performance, "auto")
    assert.equal(validateSettings({ performance: "auto" }).performance, "auto")
    assert.equal(validateSettings({ performance: "off" }).performance, "off")
    assert.equal(validateSettings({ performance: "fast" }).performance, "auto")
})

test("motion.preset is one of the presets and falls back to smooth", () => {
    assert.equal(DEFAULT_SETTINGS.motion.preset, "smooth")
    assert.equal(validateSettings({ motion: { preset: "playful" } }).motion.preset, "playful")
    assert.equal(validateSettings({ motion: { preset: "wild" } }).motion.preset, "smooth")
    assert.equal(validateSettings({ motion: { preset: 3 } }).motion.preset, "smooth")
})

test("validateSettings checks the virtual display size", () => {
    const ok = validateSettings({ displays: { virtual: { enabled: true, width: 1920, height: 1080 } } })
    assert.deepEqual(ok.displays.virtual, { enabled: true, width: 1920, height: 1080 })
    const bad = validateSettings({ displays: { virtual: { enabled: 1, width: 100, height: 99999.5 } } })
    assert.deepEqual(bad.displays.virtual, { enabled: false, width: 2388, height: 1668 })
})

test("the default look is lumen", () => assert.equal(effectiveSettings({}, {}).look.preset, "lumen"))

test("a look's settings sit under config and user values", () => {
    const looks = { mine: { name: "Mine", material: "ink", corners: "round", radius: 1, density: "cozy", fonts: {}, weight: "regular", settings: { motion: { preset: "calm" } } } }
    assert.equal(effectiveSettings({}, { look: { preset: "mine" } }, looks).motion.preset, "calm")
    assert.equal(effectiveSettings({}, { look: { preset: "mine" }, motion: { preset: "snappy" } }, looks).motion.preset, "snappy")
    assert.equal(effectiveSettings({ motion: { preset: "playful" } }, { look: { preset: "mine" } }, looks).motion.preset, "playful")
    assert.equal(effectiveSettings({ look: { preset: "mine" } }, {}, looks).motion.preset, "calm")
    assert.equal(effectiveSettings({}, { look: { preset: "mine" } }, {}).look.preset, "lumen")
})

test("resolveGlass layers over a given base", () => {
    assert.deepEqual(resolveGlass(undefined, { sheen: 0.2 }, {}).values, { sheen: 0.2 })
    assert.equal(resolveGlass(undefined, undefined).values.sheen, DEFAULT_GLASS.sheen)
})

test("settings.detail is simple unless full", () => {
    assert.equal(validateSettings({}).settings.detail, "simple")
    assert.equal(validateSettings({ settings: { detail: "full" } }).settings.detail, "full")
    assert.equal(validateSettings({ settings: { detail: 3 } }).settings.detail, "simple")
})

test("unsetPath drops a key and the empty parents it leaves", () => {
    assert.deepEqual(unsetPath({ a: { b: 1 }, c: 2 }, "a.b"), { c: 2 })
    assert.deepEqual(unsetPath({ a: { b: 1, d: 2 } }, "a.b"), { a: { d: 2 } })
    assert.deepEqual(unsetPath({ a: 1 }, "x.y"), { a: 1 })
    const src = { a: { b: 1 } }
    unsetPath(src, "a.b")
    assert.deepEqual(src, { a: { b: 1 } })
})

test("isModified is false for a value equal to the default", () => {
    const base = effectiveSettings({}, {})
    assert.equal(isModified(effectiveSettings({}, { motion: { scale: 1 } }), base, "motion.scale"), false)
    assert.equal(isModified(effectiveSettings({}, { motion: { scale: 2 } }), base, "motion.scale"), true)
    assert.equal(isModified(base, base, "access.reader"), false)
})
