import { test } from "node:test"
import assert from "node:assert/strict"
import { existsSync, readFileSync, readdirSync } from "node:fs"
import { join, relative } from "node:path"

const ROOT = new URL("../shell/", import.meta.url).pathname

function dirs(dir) {
    return [dir, ...readdirSync(dir, { withFileTypes: true }).filter(e => e.isDirectory()).flatMap(e => dirs(join(dir, e.name)))]
}

export function expected(dir) {
    const types = readdirSync(dir).filter(f => /^[A-Z]\w*\.qml$/.test(f)).sort()
    if (types.length === 0)
        return null
    const rel = relative(ROOT, dir)
    const lines = ["module " + (rel === "" ? "qs" : "qs." + rel.split("/").join("."))]
    for (const f of types) {
        const singleton = /^\s*pragma Singleton\s*$/m.test(readFileSync(join(dir, f), "utf8").split(/^import /m)[0])
        lines.push((singleton ? "singleton " : "") + f.slice(0, -4) + " 1.0 " + f)
    }
    return lines.join("\n") + "\n"
}

test("every shell directory with QML types has a matching qmldir", () => {
    for (const dir of dirs(ROOT)) {
        const want = expected(dir)
        const path = join(dir, "qmldir")
        if (want === null) {
            assert.ok(!existsSync(path), relative(ROOT, path) + " lists no types and should go")
            continue
        }
        assert.ok(existsSync(path), "missing " + relative(ROOT, path) + ", it should read:\n" + want)
        assert.equal(readFileSync(path, "utf8"), want, relative(ROOT, path) + " is out of date")
    }
})
