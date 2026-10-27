import { test } from "node:test"
import assert from "node:assert/strict"
import { url, describe, parse, validateWeather } from "../shell/lib/weather.mjs"

const sample = {
    utc_offset_seconds: 7200,
    current_units: { temperature_2m: "°C", wind_speed_10m: "km/h" },
    current: { temperature_2m: 17.6, apparent_temperature: 16.2, relative_humidity_2m: 71, weather_code: 2, wind_speed_10m: 11.4, is_day: 1 },
    hourly: {
        time: ["2026-09-24T14:00", "2026-09-24T15:00", "2026-09-24T16:00", "2026-09-24T17:00"],
        temperature_2m: [17, 18, 18.4, 16.9],
        weather_code: [2, 3, 61, 61],
        precipitation_probability: [5, 10, 60, 70],
        is_day: [1, 1, 1, 0]
    },
    daily: {
        time: ["2026-09-24", "2026-09-25"],
        weather_code: [61, 0],
        temperature_2m_max: [19.2, 21.7],
        temperature_2m_min: [11.1, 9.8],
        precipitation_probability_max: [70, 0]
    }
}

test("the forecast url asks for the right units", () => {
    assert.match(url(52.23, 21.01, "metric"), /latitude=52\.23&longitude=21\.01&/)
    assert.doesNotMatch(url(52.23, 21.01, "metric"), /fahrenheit/)
    assert.match(url(52.23, 21.01, "imperial"), /temperature_unit=fahrenheit&wind_speed_unit=mph/)
})

test("weather codes become labels and day or night glyphs", () => {
    assert.deepEqual(describe(0, true), { label: "Clear", glyph: "sunny" })
    assert.deepEqual(describe(0, false), { label: "Clear", glyph: "night" })
    assert.equal(describe(95, true).label, "Thunderstorm")
    assert.equal(describe(1234, true).label, "Unknown")
})

test("parse keeps the current conditions and only upcoming hours", () => {
    const now = Date.parse("2026-09-24T13:30:00Z")
    const w = parse(sample, now)
    assert.equal(w.temp, 18)
    assert.equal(w.feels, 16)
    assert.equal(w.day, true)
    assert.deepEqual(w.hours.map(h => h.time), ["15:00", "16:00", "17:00"])
    assert.equal(w.days[1].max, 22)
    assert.equal(w.unit, "°C")
    assert.equal(parse({}, now), null)
    assert.equal(validateWeather({ units: "kelvin", refresh: 2 }).units, "metric")
    assert.equal(validateWeather({ refresh: 2 }).refresh, 30)
})
