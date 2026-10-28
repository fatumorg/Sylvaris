import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import {
    parseOutputs, layoutKey, snapshot, sameLayout, formatMode, applyArgs, uniqueModes, fitScale, modeLabel, canApply,
    parseDdc, parseVcp, parseBacklight, brightnessTargets, stepLevel, brightnessArgs
} from "../shell/lib/displays.mjs"

const text = readFileSync(new URL("./fixtures/wlr-randr.json", import.meta.url), "utf8")
const outputs = parseOutputs(text)

test("parseOutputs reads enabled and disabled outputs", () => {
    assert.equal(outputs.length, 3)
    const dp1 = outputs.find(o => o.name === "DP-1")
    assert.deepEqual(dp1.current, { width: 1920, height: 1080, refresh: 179.964005 })
    assert.equal(dp1.x, 0)
    assert.equal(dp1.y, 500)
    assert.equal(dp1.scale, 1)
    const tv = outputs.find(o => o.name === "HDMI-A-1")
    assert.equal(tv.enabled, false)
    assert.equal(tv.current, null)
    assert.equal(tv.modes.length, 2)
})

test("parseOutputs returns an empty list for bad input", () => {
    assert.deepEqual(parseOutputs("nope"), [])
    assert.deepEqual(parseOutputs("{}"), [])
})

test("layoutKey sorts output names", () => {
    assert.equal(layoutKey(outputs), "DP-1+DP-2+HDMI-A-1")
})

test("snapshot keeps geometry of enabled outputs only", () => {
    const snap = snapshot(outputs)
    assert.deepEqual(snap["DP-2"], { enabled: true, x: 1920, y: 0, scale: 1, width: 2560, height: 1440, refresh: 200.013 })
    assert.deepEqual(snap["HDMI-A-1"], { enabled: false })
})

test("sameLayout compares with tolerance", () => {
    const a = snapshot(outputs)
    const b = JSON.parse(JSON.stringify(a))
    b["DP-1"].refresh = 179.96
    assert.equal(sameLayout(a, b), true)
    b["DP-1"].x = 10
    assert.equal(sameLayout(a, b), false)
    assert.equal(sameLayout(a, {}), false)
})

test("applyArgs builds one wlr-randr call for every output", () => {
    assert.equal(formatMode(1920, 1080, 179.964005), "1920x1080@179.964Hz")
    assert.deepEqual(applyArgs(snapshot(outputs)), [
        "--output", "DP-1", "--on", "--mode", "1920x1080@179.964Hz", "--pos", "0,500", "--scale", "1",
        "--output", "DP-2", "--on", "--mode", "2560x1440@200.013Hz", "--pos", "1920,0", "--scale", "1",
        "--output", "HDMI-A-1", "--off"
    ])
})

test("uniqueModes removes duplicates and sorts large and fast first", () => {
    const dp1 = outputs.find(o => o.name === "DP-1")
    const modes = uniqueModes(dp1.modes)
    assert.equal(modes.length, 2)
    assert.equal(modes[0].refresh, 179.964005)
    const tv = uniqueModes(outputs.find(o => o.name === "HDMI-A-1").modes)
    assert.equal(tv[0].width, 1920)
})

test("fitScale fits enabled outputs into a box", () => {
    const f = fitScale(snapshot(outputs), 564, 360, 24)
    assert.ok(Math.abs(f.factor - 516 / 4480) < 1e-9)
    assert.equal(f.minX, 0)
    assert.equal(f.minY, 0)
    assert.deepEqual(fitScale({}, 564, 360, 24), { factor: 1, minX: 0, minY: 0 })
})

test("modeLabel shows decimals when another mode rounds to the same label", () => {
    const modes = [
        { width: 1920, height: 1080, refresh: 119.93 },
        { width: 1920, height: 1080, refresh: 119.879 },
        { width: 1280, height: 720, refresh: 119.9 }
    ]
    assert.equal(modeLabel(modes[0], modes), "1920×1080 · 119.93 Hz")
    assert.equal(modeLabel(modes[1], modes), "1920×1080 · 119.88 Hz")
    assert.equal(modeLabel(modes[2], modes), "1280×720 · 120 Hz")
})

test("modeLabel is human readable", () => {
    assert.equal(modeLabel({ width: 2560, height: 1440, refresh: 200.013 }), "2560×1440 · 200 Hz")
})

test("canApply refuses layouts with every output off", () => {
    assert.equal(canApply(snapshot(outputs)), true)
    assert.equal(canApply({ "DP-1": { enabled: false }, "DP-2": { enabled: false } }), false)
    assert.equal(canApply({}), false)
    assert.equal(canApply(null), false)
})

const customText = JSON.stringify([{ name: "virtual", description: "", enabled: true, position: { x: 4480, y: 0 }, scale: 2, transform: "normal", modes: [{ width: 1920, height: 1080, refresh: 60, preferred: true, current: false }] }])

test("parseOutputs keeps an enabled output with a custom mode", () => {
    const [v] = parseOutputs(customText, { virtual: { width: 2388, height: 1668 } })
    assert.deepEqual(v.current, { width: 2388, height: 1668, refresh: 60, custom: true })
    assert.deepEqual(snapshot([v]).virtual, { enabled: true, x: 4480, y: 0, scale: 2, width: 2388, height: 1668, refresh: 60, custom: true })
    assert.equal(parseOutputs(customText)[0].current, null)
})

test("applyArgs sets a custom mode with --custom-mode", () => {
    const snap = snapshot(parseOutputs(customText, { virtual: { width: 2388, height: 1668 } }))
    assert.deepEqual(applyArgs(snap), ["--output", "virtual", "--on", "--custom-mode", "2388x1668@60.000Hz", "--pos", "4480,0", "--scale", "2"])
})

const detect = `Invalid display
   I2C bus:          /dev/i2c-9
   DRM connector:    card2-HDMI-A-2
   Monitor:          PHL:PHILIPS FTV:

Display 1
   I2C bus:          /dev/i2c-11
   DRM connector:    card2-DP-5
   drm_connector_id: 0
   Monitor:          MSI:MAG 242C:
`

test("parseDdc keeps valid displays keyed by output", () => {
    assert.deepEqual(parseDdc(detect), [{ output: "DP-5", bus: "11" }])
    assert.deepEqual(parseDdc("garbage"), [])
})

test("parseVcp reads current and max brightness", () => {
    assert.deepEqual(parseVcp("bus 11\nVCP 10 C 35 100\nbus 12\nnope\n"), { "11": 0.35 })
    assert.deepEqual(parseVcp("bus 3\nVCP 10 C 0 0\n"), {})
})

test("parseBacklight lists devices with their level", () => {
    assert.deepEqual(parseBacklight("intel_backlight,backlight,600,50%,1200\nbad\n"), [{ id: "intel_backlight", level: 0.5 }])
    assert.deepEqual(parseBacklight(""), [])
})

test("brightnessTargets maps backlight to the internal panel and ddc by connector", () => {
    const t = brightnessTargets(["eDP-1", "DP-5", "HDMI-A-2"], [{ output: "DP-5", bus: "11" }], [{ id: "amdgpu_bl0", level: 0.4 }])
    assert.deepEqual(t["eDP-1"], { kind: "backlight", id: "amdgpu_bl0", level: 0.4 })
    assert.deepEqual(t["DP-5"], { kind: "ddc", id: "11", level: -1 })
    assert.equal(t["HDMI-A-2"], undefined)
    assert.deepEqual(Object.keys(brightnessTargets(["DP-1"], [], [{ id: "acpi_video0", level: 1 }])), [])
})

test("stepLevel handles absolute, relative and bad input", () => {
    assert.equal(stepLevel(0.5, "+10"), 0.6)
    assert.equal(stepLevel(0.05, "-10"), 0)
    assert.equal(stepLevel(0.5, "80"), 0.8)
    assert.equal(stepLevel(0.5, "x"), null)
})

test("brightnessArgs never lets a backlight go fully dark", () => {
    assert.deepEqual(brightnessArgs({ kind: "backlight", id: "intel_backlight" }, 0), ["brightnessctl", "-q", "-d", "intel_backlight", "set", "1%"])
    assert.deepEqual(brightnessArgs({ kind: "ddc", id: "11" }, 0.354), ["ddcutil", "setvcp", "10", "35", "--bus", "11", "--noverify"])
})
