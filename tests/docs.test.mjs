import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync, existsSync } from "node:fs"
import { dirname, join, normalize } from "node:path"
import { fileURLToPath } from "node:url"
import { PARTS } from "../shell/lib/settings.mjs"
import { render } from "../site/markdown.mjs"
import { settingsReference } from "../site/reference.mjs"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const docs = join(root, "docs")
const pages = readdirSync(docs, { recursive: true }).filter(f => f.endsWith(".md")).map(f => join(docs, f))

test("docs/reference/settings.md matches the shell's defaults", () => {
    assert.equal(readFileSync(join(docs, "reference/settings.md"), "utf8"), settingsReference(), "run: node site/reference.mjs > docs/reference/settings.md")
})

test("every part has a page", () => {
    for (const name of Object.keys(PARTS)) {
        const page = name === "plugins" ? "plugins/README.md" : ["diver", "fatest", "rgb", "temp"].includes(name) ? "plugins/" + name + ".md" : "parts/" + name + ".md"
        assert.ok(existsSync(join(docs, page)), name + " needs docs/" + page)
    }
})

test("links between pages and to their sections resolve", () => {
    const ids = {}
    const idsOf = file => ids[file] || (ids[file] = new Set(render(readFileSync(file, "utf8")).headings.map(h => h.id)))
    for (const file of pages) {
        const text = readFileSync(file, "utf8").replace(/```[\s\S]*?```/g, "").replace(/`[^`]*`/g, "")
        for (const m of text.matchAll(/\]\(([^)\s]+)\)/g)) {
            const href = m[1]
            if (/^[a-z]+:/.test(href))
                continue
            const [path, anchor] = href.split("#")
            const target = path === "" ? file : normalize(join(dirname(file), path))
            assert.ok(existsSync(target), file.slice(root.length) + " links to missing " + href)
            if (anchor && target.endsWith(".md"))
                assert.ok(idsOf(target).has(anchor), file.slice(root.length) + " links to missing section " + href)
        }
    }
})

test("docs read like a person wrote them: no em or en dashes", () => {
    for (const file of pages)
        assert.equal(/[–—]/.test(readFileSync(file, "utf8")), false, file.slice(root.length))
})
