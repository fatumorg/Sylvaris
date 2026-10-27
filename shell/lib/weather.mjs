export const DEFAULT_WEATHER = { enabled: true, units: "metric", refresh: 30 }

const CODES = [
    [[0], "Clear", "sunny", "night"],
    [[1, 2], "Partly cloudy", "partlyCloudy", "partlyNight"],
    [[3], "Overcast", "cloudy", "cloudy"],
    [[45, 48], "Fog", "fog", "fog"],
    [[51, 53, 55, 56, 57], "Drizzle", "rain", "rain"],
    [[61, 63, 66, 80, 81], "Rain", "rain", "rain"],
    [[65, 67, 82], "Heavy rain", "pouring", "pouring"],
    [[71, 73, 75, 77, 85, 86], "Snow", "snow", "snow"],
    [[95, 96, 99], "Thunderstorm", "storm", "storm"]
]

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

export function validateWeather(raw) {
    const w = isObject(raw) ? raw : {}
    return Object.assign({}, w, {
        enabled: w.enabled !== false,
        units: w.units === "imperial" ? "imperial" : "metric",
        refresh: Number.isInteger(w.refresh) && w.refresh >= 10 && w.refresh <= 360 ? w.refresh : DEFAULT_WEATHER.refresh
    })
}

export function url(lat, lon, units) {
    const imperial = units === "imperial"
    return "https://api.open-meteo.com/v1/forecast?latitude=" + lat.toFixed(2) + "&longitude=" + lon.toFixed(2)
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
        + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        + "&timezone=auto&forecast_days=6"
        + (imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "")
}

export function describe(code, day) {
    for (const [codes, label, dayGlyph, nightGlyph] of CODES) {
        if (codes.indexOf(code) >= 0)
            return { label: label, glyph: day === false ? nightGlyph : dayGlyph }
    }
    return { label: "Unknown", glyph: "cloudy" }
}

export function parse(data, nowMs) {
    if (!isObject(data) || !isObject(data.current) || !isObject(data.hourly) || !isObject(data.daily))
        return null
    const c = data.current
    const h = data.hourly
    const d = data.daily
    const now = nowMs === undefined ? Date.now() : nowMs
    const hours = []
    for (let i = 0; i < h.time.length && hours.length < 12; i++) {
        if (Date.parse(h.time[i] + "Z") - (data.utc_offset_seconds || 0) * 1000 + 3600000 <= now)
            continue
        hours.push({ time: h.time[i].slice(11, 16), temp: Math.round(h.temperature_2m[i]), code: h.weather_code[i], rain: h.precipitation_probability[i] || 0, day: h.is_day[i] === 1 })
    }
    const days = d.time.map((t, i) => ({ date: t, max: Math.round(d.temperature_2m_max[i]), min: Math.round(d.temperature_2m_min[i]), code: d.weather_code[i], rain: d.precipitation_probability_max[i] || 0 }))
    return {
        temp: Math.round(c.temperature_2m),
        feels: Math.round(c.apparent_temperature),
        humidity: Math.round(c.relative_humidity_2m),
        wind: Math.round(c.wind_speed_10m),
        code: c.weather_code,
        day: c.is_day === 1,
        hours: hours,
        days: days,
        unit: (data.current_units && data.current_units.temperature_2m) || "°C",
        windUnit: (data.current_units && data.current_units.wind_speed_10m) || "km/h"
    }
}
