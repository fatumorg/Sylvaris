import { test } from "node:test"
import assert from "node:assert/strict"
import { render, slug, inline } from "../site/markdown.mjs"

test("slug makes stable ids from headings, Polish letters included", () => {
    assert.equal(slug("SylBar"), "sylbar")
    assert.equal(slug("Start it with your compositor"), "start-it-with-your-compositor")
    assert.equal(slug("Polityka prywatności"), "polityka-prywatnosci")
    assert.equal(slug("`capture.fps` and more!"), "capture-fps-and-more")
})

test("headings get ids, deduplicated, and are collected", () => {
    const r = render("# Title\n\n## Setup\n\ntext\n\n## Setup\n")
    assert.equal(r.title, "Title")
    assert.match(r.html, /<h2 id="setup"><a class="anchor" href="#setup"[^>]*>/)
    assert.match(r.html, /<h2 id="setup-2">/)
    assert.deepEqual(r.headings.map(h => [h.level, h.id]), [[1, "title"], [2, "setup"], [2, "setup-2"]])
})

test("paragraphs join lines and escape html", () => {
    assert.equal(render("one\ntwo <b>\n").html, "<p>one two &lt;b&gt;</p>\n")
})

test("inline code, bold, italics, links and images", () => {
    assert.equal(inline("run `a <b>` **now** and _then_ *maybe*"), "run <code>a &lt;b&gt;</code> <strong>now</strong> and <em>then</em> <em>maybe</em>")
    assert.equal(inline("[docs](guide.md) ![logo](a.svg)", h => h.replace(".md", ".html")), "<a href=\"guide.html\">docs</a> <img src=\"a.svg\" alt=\"logo\" loading=\"lazy\">")
    assert.equal(inline("`**not bold**`"), "<code>**not bold**</code>")
    assert.equal(inline("snake_case_word stays"), "snake_case_word stays")
    assert.equal(inline("[x](javascript:alert(1))"), "x")
})

test("fenced code keeps text and marks the language", () => {
    const r = render("```nix\n{ a = \"<b>\"; }\n```\n")
    assert.equal(r.html, "<pre data-lang=\"nix\"><code>{ a = &quot;&lt;b&gt;&quot;; }</code></pre>\n")
})

test("lists, ordered lists and continuation lines", () => {
    assert.equal(render("- one\n  more\n- two\n").html, "<ul>\n<li>one more</li>\n<li>two</li>\n</ul>\n")
    assert.equal(render("1. a\n2. b\n").html, "<ol>\n<li>a</li>\n<li>b</li>\n</ol>\n")
})

test("tables with alignment", () => {
    const r = render("| A | B |\n|---|:---:|\n| `x` | y |\n")
    assert.equal(r.html, "<div class=\"table\"><table>\n<thead><tr><th>A</th><th class=\"c\">B</th></tr></thead>\n<tbody>\n<tr><td><code>x</code></td><td class=\"c\">y</td></tr>\n</tbody></table></div>\n")
})

test("pipes inside code spans do not split table cells", () => {
    const r = render("| Command | Does |\n|---|---|\n| `wm workspace <n\\|next>` | go |\n")
    assert.match(r.html, /<td><code>wm workspace &lt;n\|next&gt;<\/code><\/td><td>go<\/td>/)
})

test("blockquotes and rules", () => {
    assert.equal(render("> **Experimental.** Careful.\n\n---\n").html, "<blockquote><p><strong>Experimental.</strong> Careful.</p>\n</blockquote>\n<hr>\n")
})

test("the built site loads nothing from other servers and every page links to the legal pages", async () => {
    const { execFileSync } = await import("node:child_process")
    const { mkdtempSync, readdirSync, readFileSync, rmSync } = await import("node:fs")
    const { tmpdir } = await import("node:os")
    const { join } = await import("node:path")
    const out = mkdtempSync(join(tmpdir(), "sylsite-"))
    try {
        execFileSync("node", [new URL("../site/build.mjs", import.meta.url).pathname], { env: Object.assign({}, process.env, { SITE_OUT: out, SITE_NO_MEDIA: "1" }), stdio: "ignore" })
        const files = readdirSync(out, { recursive: true }).map(String)
        const pages = files.filter(f => f.endsWith(".html"))
        assert.ok(pages.length > 40)
        for (const f of files.filter(f => /\.(html|css|js)$/.test(f))) {
            const text = readFileSync(join(out, f), "utf8")
            assert.equal(/(src|srcset|poster)=["']https?:/i.test(text), false, f + " loads something from another server")
            assert.equal(/<link[^>]+href=["']https?:/i.test(text), false, f + " links a stylesheet or font from another server")
            assert.equal(/url\(["']?https?:/i.test(text), false, f + " pulls a url() from another server")
            if (f.endsWith(".js"))
                assert.equal(/localStorage|sessionStorage|indexedDB|document\.cookie/.test(text), false, f + " stores something in the browser")
            if (f.endsWith(".html"))
                assert.equal(/<script(?![^>]*\ssrc=)[^>]*>|\sstyle=|\son[a-z]+=/i.test(text), false, f + " has inline script or style, which the Content-Security-Policy blocks")
        }
        for (const f of pages.filter(p => !p.startsWith("legal/")))
            assert.match(readFileSync(join(out, f), "utf8"), /polityka-prywatnosci\.html/, f)
    } finally {
        rmSync(out, { recursive: true, force: true })
    }
})

test("every page links the forum, shares a local preview image and embeds nothing", async () => {
    const { execFileSync } = await import("node:child_process")
    const { mkdtempSync, readdirSync, readFileSync, rmSync, existsSync } = await import("node:fs")
    const { tmpdir } = await import("node:os")
    const { join } = await import("node:path")
    const { FORUM } = await import("../site/content.mjs")
    const out = mkdtempSync(join(tmpdir(), "sylsite-"))
    try {
        execFileSync("node", [new URL("../site/build.mjs", import.meta.url).pathname], { env: Object.assign({}, process.env, { SITE_OUT: out, SITE_NO_MEDIA: "1" }), stdio: "ignore" })
        const pages = readdirSync(out, { recursive: true }).map(String).filter(f => f.endsWith(".html"))
        for (const f of pages) {
            const text = readFileSync(join(out, f), "utf8")
            assert.ok(text.includes("href=\"" + FORUM + "\""), f + " does not link the forum")
            assert.equal(/<iframe/i.test(text), false, f + " embeds a frame")
            const og = /<meta property="og:image" content="([^"]+)"/.exec(text)
            assert.ok(og !== null && og[1].startsWith("/"), f + " has no local og:image")
            assert.ok(existsSync(join(out, og[1])), og[1] + " is missing")
            assert.match(text, /<meta name="twitter:card" content="summary_large_image">/, f)
        }
        assert.match(readFileSync(join(out, "index.html"), "utf8"), /class="forum-notice"/)
        const press = readFileSync(join(out, "docs/press.html"), "utf8")
        const shots = [...press.matchAll(/<img src="([^"]+)"/g)].map(m => m[1])
        assert.ok(shots.length >= 6, "the press kit shows its screenshots")
        for (const s of shots)
            assert.ok(existsSync(join(out, "docs", s)), s + " is missing from the built site")
    } finally {
        rmSync(out, { recursive: true, force: true })
    }
})
