import { test } from "node:test"
import assert from "node:assert/strict"
import { existsSync, readFileSync, readdirSync } from "node:fs"
import { join } from "node:path"

const ROOT = new URL("../shell/", import.meta.url).pathname
const FILL = /^\s*color:\s.*Theme\.(surface|node|glass|tint|tintSoft|tintStrong)\b/
const PLAIN_MID = /^\s*color:\s*Theme\.tintMid\s*$/
const ALLOW = {
    "center/MediaCard.qml": ["color: Theme.surface"],
    "components/HaloCore.qml": ["color: Qt.lighter(Theme.surface, 1.5)"]
}

function qmlFiles(dir) {
    if (!existsSync(join(ROOT, dir)))
        return []
    return readdirSync(join(ROOT, dir)).filter(f => f.endsWith(".qml")).map(f => join(dir, f))
}

test("no surface paints its own fill outside Glass", () => {
    const offenders = []
    for (const file of [...qmlFiles("components"), ...qmlFiles("center"), ...qmlFiles("theme")]) {
        if (file === "components/Glass.qml")
            continue
        readFileSync(join(ROOT, file), "utf8").split("\n").forEach((line, i) => {
            if ((FILL.test(line) || PLAIN_MID.test(line)) && !(ALLOW[file] || []).includes(line.trim()))
                offenders.push(file + ":" + (i + 1) + ": " + line.trim())
        })
    }
    assert.deepEqual(offenders, [])
})

test("every part's own panel glass names its role so looks can restyle it", () => {
    const roots = ["bar/SylBar.qml", "bar/BarGroup.qml", "deck/SylDeck.qml", "center/SylCenter.qml", "island/IslandBody.qml", "notify/NotificationCard.qml", "pad/SylPad.qml", "settings/SylSettings.qml", "switcher/SylSwitch.qml", "polkit/SylPolkit.qml", "greet/GreetView.qml", "components/Popup.qml"]
    const missing = roots.filter(f => !/Glass \{\n\s+role: /.test(readFileSync(join(ROOT, f), "utf8")))
    assert.deepEqual(missing, [])
})

test("Glass takes its levels from its role, not straight from Resin", () => {
    const text = readFileSync(join(ROOT, "components/Glass.qml"), "utf8")
    assert.deepEqual(text.match(/Resin\.\w+/g), ["Resin.values", "Resin.litAlpha"])
})
