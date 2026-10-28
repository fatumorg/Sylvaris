import { DEFAULT_SETTINGS, DEFAULT_CONFIG, screenKey } from "../shell/lib/settings.mjs"

const PAGES = {
    bar: "parts/bar.md", deck: "parts/deck.md", center: "parts/center.md", clock: "parts/clock.md", notifications: "parts/notify.md",
    pad: "parts/pad.md", media: "parts/media.md", power: "parts/power.md", paper: "parts/paper.md", switcher: "parts/switcher.md",
    lock: "parts/lock.md", clip: "parts/clip.md", capture: "parts/capture.md", access: "parts/access.md", island: "parts/island.md",
    sync: "parts/sync.md", diver: "plugins/diver.md", rgb: "plugins/rgb.md", plugins: "plugins/README.md", weather: "parts/clock.md", sky: "parts/clock.md",
    placement: "configuration.md#where-panels-open", screens: "configuration.md#one-screen-at-a-time", parts: "configuration.md#turning-parts-off",
    motion: "look.md#motion-and-performance", glass: "look.md#resin-glass", look: "look.md#looks", keybinds: "keybinds.md", eq: "parts/media.md",
    nightLight: "parts/center.md", displays: "parts/center.md#displays", hotspot: "parts/center.md#hotspot", toggleState: "configuration.md#custom-toggles",
    constellation: "parts/settings.md", performance: "look.md#motion-and-performance", iconTint: "look.md#motion-and-performance",
    corners: "configuration.md#hot-corners"
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function leaves(obj, prefix) {
    const out = []
    for (const key of Object.keys(obj)) {
        const path = prefix === "" ? key : prefix + "." + key
        if (isObject(obj[key]) && Object.keys(obj[key]).length > 0)
            out.push(...leaves(obj[key], path))
        else
            out.push([path, obj[key]])
    }
    return out
}

function cell(value) {
    const json = JSON.stringify(value)
    return "`" + (json.length > 60 ? json.slice(0, 57) + "..." : json).replace(/\|/g, "\\|") + "`"
}

export function settingsReference() {
    const lines = [
        "# Settings reference",
        "",
        "Every key Sylvaris reads from `settings.json`, with its default. The same keys work in `config.json` and as Home Manager options under `programs.sylvaris`, and `sylvaris set <key> <value>` changes any of them. Keys marked per screen can also be set for one screen under `screens.<output>` (see [one screen at a time](../configuration.md#one-screen-at-a-time)).",
        "",
        "This page is generated from the shell's defaults by `node site/reference.mjs`, so it always matches the code."
    ]
    for (const top of Object.keys(DEFAULT_SETTINGS).filter(k => k !== "version")) {
        lines.push("", "## " + top, "")
        if (PAGES[top])
            lines.push("Explained in [" + PAGES[top].replace(/#.*/, "").replace(/\.md$/, "").replace(/^parts\//, "").replace(/^plugins\/README$/, "plugins") + "](../" + PAGES[top] + ").", "")
        lines.push("| Key | Default | Per screen |", "|---|---|:---:|")
        const value = DEFAULT_SETTINGS[top]
        const rows = isObject(value) && Object.keys(value).length > 0 ? leaves(value, top) : [[top, value]]
        for (const [path, v] of rows)
            lines.push("| `" + path + "` | " + cell(v) + " | " + (screenKey(path) ? "yes" : "") + " |")
    }
    lines.push("", "## config.json only", "", "These keys only make sense in `config.json` (or `programs.sylvaris.settings`), because Sylvaris never writes that file.", "", "| Key | Default |", "|---|---|")
    for (const key of Object.keys(DEFAULT_CONFIG).filter(k => k !== "version"))
        lines.push("| `" + key + "` | " + cell(DEFAULT_CONFIG[key]) + " |")
    return lines.join("\n") + "\n"
}

if (import.meta.url === "file://" + process.argv[1])
    process.stdout.write(settingsReference())
