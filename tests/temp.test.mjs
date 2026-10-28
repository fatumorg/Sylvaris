import { test } from "node:test"
import assert from "node:assert/strict"
import { parseLine, parseLegacy, level, headline, pushHistory, alerts, overlayShown, backoff, sensorId, validateTemp, DEFAULT_TEMP, compact, devices, headroom, streams, picked, hottest, short } from "../shell/lib/temp.mjs"

const cpu = (v, extra) => Object.assign({ group: "k10temp", label: "Tctl", value: v, unit: "°C", kind: "cpu", device: "Ryzen 7 7800X3D", warn: 75, hot: 90 }, extra)
const LINE = JSON.stringify({
    time: 1, sensors: [
        cpu(54),
        { group: "amdgpu", label: "edge", value: 61, unit: "°C", kind: "gpu", device: "RX 7900", warn: 75, hot: 90 },
        { group: "amdgpu", label: "junction", value: 70, unit: "°C", kind: "gpu", device: "RX 7900", warn: 75, hot: 90 },
        { group: "nvme", label: "Composite", value: 41, unit: "°C", kind: "storage", device: "Samsung 990", warn: 50, hot: 65 },
        { group: "nvme", label: "Composite", value: 48, unit: "°C", kind: "storage", device: "WD SN850", warn: 50, hot: 65 },
        { group: "nct6799", label: "fan1", value: 900, unit: "RPM", kind: "other", device: "Board", warn: null, hot: null }
    ]
})

test("garbage lines give null and good lines parse", () => {
    assert.equal(parseLine("not json"), null)
    assert.equal(parseLine("{\"time\":1}"), null)
    assert.equal(parseLine("[1,2]"), null)
    assert.equal(parseLine(""), null)
    const r = parseLine(LINE)
    assert.equal(r.sensors.length, 6)
    assert.equal(parseLine(JSON.stringify({ time: 1, sensors: [{ label: "x", value: "hot" }] })).sensors.length, 0)
    assert.equal(parseLegacy("[{\"label\":\"a\",\"value\":1,\"unit\":\"°C\",\"kind\":\"cpu\"}]")[0].warn, null)
})

test("level reads warn and hot, and falls back to TempInfoCLI 0.2", () => {
    assert.equal(level(cpu(54)), "cool")
    assert.equal(level(cpu(80)), "warm")
    assert.equal(level(cpu(80, { warn: 85 })), "cool")
    assert.equal(level(cpu(91, { warn: null, hot: null })), "hot")
    assert.equal(level({ label: "d", value: 55, unit: "°C", kind: "storage", warn: null, hot: null }), "warm")
    assert.equal(level({ label: "fan", value: 900, unit: "RPM", kind: "other" }), "none")
    assert.equal(headroom(cpu(45)), 0.5)
})

test("headline picks the cpu, each gpu core and the hottest drive", () => {
    const h = headline(parseLine(LINE).sensors)
    assert.deepEqual(h.map(s => s.label + "@" + s.device), ["Tctl@Ryzen 7 7800X3D", "edge@RX 7900", "Composite@WD SN850"])
    assert.equal(compact(parseLine(LINE).sensors), "CPU 54° · GPU 61° · SSD 48°")
    assert.equal(devices(parseLine(LINE).sensors)[0].kind, "cpu")
})

test("history keeps the last samples per sensor", () => {
    let h = {}
    for (let i = 0; i < 130; i++)
        h = pushHistory(h, [cpu(i)])
    assert.equal(h[sensorId(cpu(0))].length, 120)
    assert.equal(h[sensorId(cpu(0))][119], 129)
})

test("alerts fire once, wait out the cooldown and a drop, then fire again", () => {
    let r = alerts({}, [cpu(92)], 0, 300)
    assert.equal(r.fire.length, 1)
    r = alerts(r.state, [cpu(93)], 1000, 300)
    assert.equal(r.fire.length, 0)
    r = alerts(r.state, [cpu(60)], 2000, 300)
    r = alerts(r.state, [cpu(95)], 3000, 300)
    assert.equal(r.fire.length, 0)
    r = alerts(r.state, [cpu(60)], 301000, 300)
    r = alerts(r.state, [cpu(95)], 302000, 300)
    assert.equal(r.fire.length, 1)
})

test("the overlay follows its show mode", () => {
    assert.equal(overlayShown({ show: "apps", apps: ["steam_app_.*"] }, { class: "steam_app_123" }), true)
    assert.equal(overlayShown({ show: "apps", apps: ["steam_app_.*", "("] }, { class: "firefox" }), false)
    assert.equal(overlayShown({ show: "fullscreen" }, { fullscreen: false }), false)
    assert.equal(overlayShown({ show: "fullscreen" }, { fullscreen: true }), true)
    assert.equal(overlayShown({ show: "toggle" }, {}, true), true)
    assert.equal(overlayShown({ show: "off" }, { fullscreen: true }, true), false)
})

test("restarts back off up to a minute", () => {
    assert.deepEqual([0, 1, 2, 3].map(backoff), [1000, 2000, 4000, 8000])
    assert.equal(backoff(10), 60000)
})

test("temp settings validate", () => {
    assert.deepEqual(validateTemp({}), DEFAULT_TEMP)
    assert.equal(validateTemp({ overlay: { show: "always", scale: 9 } }).overlay.show, "off")
    assert.equal(validateTemp({ overlay: { scale: 9 } }).overlay.scale, 3)
})

test("0.3 and newer stream, 0.2 is polled", () => {
    assert.equal(streams("tempinfo 0.3.0"), true)
    assert.equal(streams("tempinfo 1.0.0"), true)
    assert.equal(streams("tempinfo 0.2.1"), false)
    assert.equal(streams(""), false)
})

test("pinned sensors win over the headline and the hottest one leads", () => {
    const all = parseLine(LINE).sensors
    assert.deepEqual(picked(all, ["Board/fan1"]).map(s => s.label), ["fan1"])
    assert.equal(picked(all, ["gone/x"]).length, 3)
    assert.equal(hottest(all).label, "junction")
    assert.equal(hottest(picked(all, [])).device, "WD SN850")
    assert.equal(short(all[5]), "fan1 900 RPM")
    assert.equal(hottest([]), null)
})
