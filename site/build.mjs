import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync, copyFileSync, cpSync, rmSync, statSync } from "node:fs"
import { dirname, join, relative, normalize, posix } from "node:path"
import { fileURLToPath } from "node:url"
import { execFileSync } from "node:child_process"
import { render, escape } from "./markdown.mjs"
import { PARTS, NAV, LEGAL, REPO, FORUM } from "./content.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, "..")
const docs = join(root, "docs")
const dist = process.env.SITE_OUT || join(here, "dist")
const strict = process.argv.includes("--strict")
const VERSION = /VERSION = "([^"]+)"/.exec(readFileSync(join(root, "shell/lib/version.mjs"), "utf8"))[1]

function operator() {
    const file = existsSync(join(here, "operator.json")) ? join(here, "operator.json") : join(here, "operator.example.json")
    const data = JSON.parse(readFileSync(file, "utf8"))
    const missing = ["email"].filter(k => typeof data[k] !== "string" || data[k].trim() === "")
    return { data: data, missing: missing, file: relative(root, file) }
}

const op = operator()

function fill(text) {
    return text.replace(/\{\{(\w+)\}\}/g, (m, key) => {
        const v = op.data[key]
        if (v === undefined || v === null || String(v).trim() === "")
            return "<mark class=\"todo\">[" + key + "]</mark>"
        return escape(String(v))
    })
}

function write(path, text) {
    mkdirSync(dirname(path), { recursive: true })
    writeFileSync(path, text)
}

function urlOf(docPath) {
    return "docs/" + docPath.replace(/(^|\/)README\.md$/, "$1index.html").replace(/\.md$/, ".html")
}

function linker(fromDoc) {
    return href => {
        if (/^[a-z]+:/i.test(href) || href.startsWith("#"))
            return href
        const [path, anchor] = href.split("#")
        const target = normalize(join(dirname(join("docs", fromDoc)), path)).split("\\").join("/")
        const tail = anchor ? "#" + anchor : ""
        if (target.startsWith("docs/") && target.endsWith(".md"))
            return posix.relative(posix.dirname(urlOf(fromDoc)), urlOf(target.slice(5))) + tail
        if (target.startsWith("docs/assets/"))
            return posix.relative(posix.dirname(urlOf(fromDoc)), target)
        return REPO + "/blob/main/" + target + tail
    }
}

function plain(html) {
    return html.replace(/<[^>]+>/g, " ").replace(/&quot;/g, "\"").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim()
}

function describe(html) {
    const m = /<p>([\s\S]*?)<\/p>/.exec(html)
    const text = m ? plain(m[1]) : ""
    return text.length > 158 ? text.slice(0, 155).replace(/\s\S*$/, "") + "..." : text
}

const ICON = {
    search: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><circle cx=\"10.5\" cy=\"10.5\" r=\"6.5\"/><path d=\"m15.5 15.5 5 5\"/></svg>",
    github: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M12 2.5a9.5 9.5 0 0 0-3 18.5c.5.1.7-.2.7-.5v-1.7c-2.7.6-3.3-1.2-3.3-1.2-.4-1.1-1.1-1.4-1.1-1.4-.9-.6.1-.6.1-.6 1 .1 1.5 1 1.5 1 .9 1.5 2.3 1.1 2.9.8.1-.6.3-1.1.6-1.3-2.2-.2-4.4-1.1-4.4-4.8 0-1.1.4-1.9 1-2.6-.1-.3-.4-1.3.1-2.6 0 0 .8-.3 2.6 1a9 9 0 0 1 4.8 0c1.8-1.3 2.6-1 2.6-1 .5 1.3.2 2.3.1 2.6.6.7 1 1.5 1 2.6 0 3.7-2.3 4.6-4.4 4.8.3.3.6.9.6 1.8v2.7c0 .3.2.6.7.5A9.5 9.5 0 0 0 12 2.5Z\"/></svg>",
    menu: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M4 7h16M4 12h16M4 17h10\"/></svg>",
    copy: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><rect x=\"8\" y=\"8\" width=\"12\" height=\"12\" rx=\"3\"/><path d=\"M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2\"/></svg>"
}

function themeDots() {
    const themes = [["warm", "Warm"], ["moss", "Moss"], ["tide", "Tide"], ["rose", "Rose"], ["ash", "Ash"]]
    return "<div class=\"themes\" role=\"group\" aria-label=\"Colour of this page\">" + themes.map(([id, label], i) =>
        "<button type=\"button\" class=\"dot dot-" + id + "\" data-theme-pick=\"" + id + "\" aria-pressed=\"" + (i === 0) + "\" title=\"" + label + "\"><span class=\"sr\">" + label + "</span></button>").join("") + "</div>"
}

function header(base, current) {
    const link = (href, label, key) => "<a href=\"" + base + href + "\"" + (current === key ? " aria-current=\"page\"" : "") + ">" + label + "</a>"
    return "<header class=\"top\"><div class=\"top-in\">" +
        "<a class=\"brand\" href=\"" + base + "index.html\"><img src=\"" + base + "assets/logo.svg\" alt=\"\" width=\"30\" height=\"30\"><span>Sylvaris</span></a>" +
        "<nav class=\"main-nav\" aria-label=\"Main\">" + link("docs/index.html", "Docs", "docs") + link("docs/parts/index.html", "Parts", "parts") + link("docs/plugins/index.html", "Plugins", "plugins") + link("docs/nix.html", "Nix", "nix") + "<a href=\"" + FORUM + "\" rel=\"noopener\">Community</a></nav>" +
        "<div class=\"top-tools\"><button type=\"button\" class=\"search-open\" data-search-open aria-haspopup=\"dialog\">" + ICON.search + "<span>Search</span><kbd>Ctrl K</kbd></button>" +
        themeDots() +
        "<a class=\"gh\" href=\"" + REPO + "\" aria-label=\"Sylvaris on GitHub\">" + ICON.github + "</a></div>" +
        "</div></header>"
}

function footer(base) {
    const l = (href, label) => "<a href=\"" + base + href + "\">" + label + "</a>"
    return "<footer class=\"foot\"><div class=\"foot-in\">" +
        "<div class=\"foot-brand\"><img src=\"" + base + "assets/logo.svg\" alt=\"\" width=\"44\" height=\"44\"><p>Sylvaris " + VERSION + ". Free software under the MIT licence.<br>This site sets no cookies, keeps nothing in your browser and loads nothing from other servers.</p></div>" +
        "<nav aria-label=\"Documentation\"><h2>Read</h2>" + l("docs/start.html", "Getting started") + l("docs/parts/index.html", "Parts") + l("docs/commands.html", "Commands") + l("docs/nix.html", "Nix and Home Manager") + l("docs/reference/settings.html", "Settings reference") + "</nav>" +
        "<nav aria-label=\"Project\"><h2>Project</h2><a href=\"" + REPO + "\">Source on GitHub</a><a href=\"" + REPO + "/blob/main/CHANGELOG.md\">Changelog</a><a href=\"" + REPO + "/issues\">Report a problem</a><a href=\"" + FORUM + "\">Community forum</a>" + l("docs/press.html", "Press kit") + "<a href=\"" + REPO + "/blob/main/LICENSE\">MIT licence</a></nav>" +
        "<nav aria-label=\"Legal\" lang=\"pl\"><h2>Informacje prawne</h2>" + LEGAL.filter(p => p.lang === "pl").map(p => l("legal/" + p.slug + ".html", p.title)).join("") + "<span class=\"foot-en\" lang=\"en\">In English: " + LEGAL.filter(p => p.lang === "en").map(p => l("legal/" + p.slug + ".html", p.short)).join(", ") + "</span></nav>" +
        "</div></footer>"
}

function searchDialog() {
    return "<dialog class=\"search\" aria-label=\"Search the documentation\"><form method=\"dialog\" class=\"search-box\"><label class=\"sr\" for=\"q\">Search the documentation</label>" + ICON.search +
        "<input id=\"q\" type=\"search\" autocomplete=\"off\" spellcheck=\"false\" placeholder=\"Search parts, settings, commands\"><button type=\"submit\" class=\"search-close\">Esc</button></form>" +
        "<ol class=\"results\" role=\"listbox\" aria-label=\"Results\"></ol><p class=\"search-hint\">Arrows to move, Enter to open.</p></dialog>"
}

function page({ base, title, description, body, current, bodyClass, lang }) {
    return "<!doctype html>\n<html lang=\"" + (lang || "en") + "\"" + (bodyClass === "home" ? " class=\"home-root\"" : "") + ">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
        "<title>" + escape(title) + "</title>\n<meta name=\"description\" content=\"" + escape(description || "") + "\">\n" +
        "<meta name=\"color-scheme\" content=\"dark light\">\n<meta name=\"theme-color\" content=\"#140f0c\">\n" +
        "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'self'; img-src 'self' data:; media-src 'self'; style-src 'self'; script-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'\">\n" +
        "<meta name=\"referrer\" content=\"strict-origin-when-cross-origin\">\n" +
        "<meta property=\"og:title\" content=\"" + escape(title) + "\">\n<meta property=\"og:description\" content=\"" + escape(description || "") + "\">\n" +
        "<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:image\" content=\"/docs/assets/social.png\">\n<meta name=\"twitter:card\" content=\"summary_large_image\">\n" +
        "<link rel=\"icon\" href=\"" + base + "assets/logo.svg\" type=\"image/svg+xml\">\n" +
        "<link rel=\"preload\" href=\"" + base + "assets/fonts/atkinson-400.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>\n" +
        "<link rel=\"preload\" href=\"" + base + "assets/fonts/fraunces-600.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>\n" +
        "<link rel=\"stylesheet\" href=\"" + base + "assets/site.css\">\n<script src=\"" + base + "assets/site.js\" defer></script>\n</head>\n" +
        "<body class=\"" + (bodyClass || "") + "\" data-base=\"" + base + "\">\n<a class=\"skip\" href=\"#content\">Skip to content</a>\n" +
        header(base, current) + "\n" + body + "\n" + footer(base) + "\n" + searchDialog() + "\n</body>\n</html>\n"
}

function sidebar(currentDoc, base) {
    return "<nav class=\"side\" aria-label=\"Documentation\"><details class=\"side-fold\" open><summary>" + ICON.menu + "<span>All pages</span></summary>" +
        NAV.map(group => "<div class=\"side-group\"><h2>" + group.title + "</h2><ul>" + group.items.map(([doc, label]) =>
            "<li><a href=\"" + base + urlOf(doc) + "\"" + (doc === currentDoc ? " aria-current=\"page\"" : "") + ">" + label + "</a></li>").join("") + "</ul></div>").join("") +
        "</details></nav>"
}

function toc(headings) {
    const items = headings.filter(h => h.level === 2 || h.level === 3)
    if (items.length < 2)
        return ""
    return "<aside class=\"toc\" aria-label=\"On this page\"><h2>On this page</h2><ol>" + items.map(h => "<li class=\"l" + h.level + "\"><a href=\"#" + h.id + "\">" + escape(h.text) + "</a></li>").join("") + "</ol></aside>"
}

function flatNav() {
    return NAV.flatMap(g => g.items)
}

function sectionOf(doc) {
    if (doc.startsWith("parts/"))
        return "parts"
    if (doc.startsWith("plugins/"))
        return "plugins"
    if (doc === "nix.md")
        return "nix"
    return "docs"
}

function buildDocs(index) {
    const files = readdirSync(docs, { recursive: true }).map(f => String(f).split("\\").join("/")).filter(f => f.endsWith(".md"))
    const order = flatNav().map(i => i[0])
    for (const doc of files) {
        const source = readFileSync(join(docs, doc), "utf8")
        const r = render(source, linker(doc))
        const out = urlOf(doc)
        const base = "../".repeat(out.split("/").length - 1)
        const i = order.indexOf(doc)
        const prev = i > 0 ? flatNav()[i - 1] : null
        const next = i >= 0 && i < order.length - 1 ? flatNav()[i + 1] : null
        const nav = (item, cls, word) => item ? "<a class=\"" + cls + "\" href=\"" + base + urlOf(item[0]) + "\"><small>" + word + "</small>" + item[1] + "</a>" : "<span></span>"
        const group = NAV.find(g => g.items.some(it => it[0] === doc))
        const body = "<div class=\"doc-shell\">" + sidebar(doc, base) +
            "<main id=\"content\" class=\"doc\"><p class=\"crumb\">" + (group ? group.title : "Documentation") + "</p><article class=\"prose\">" + r.html + "</article>" +
            "<div class=\"doc-foot\"><a class=\"edit\" href=\"" + REPO + "/blob/main/docs/" + doc + "\">Edit this page on GitHub</a>" +
            "<nav class=\"pager\" aria-label=\"Next and previous\">" + nav(prev, "prev", "Previous") + nav(next, "next", "Next") + "</nav></div></main>" +
            toc(r.headings) + "</div>"
        write(join(dist, out), page({ base: base, title: (r.title || "Sylvaris") + " · Sylvaris", description: describe(r.html), body: body, current: sectionOf(doc), bodyClass: "docs" }))
        index.push({
            t: r.title,
            u: out,
            h: r.headings.filter(h => h.level > 1).map(h => [h.id, h.text]),
            x: plain(r.html).slice(0, 1600)
        })
    }
}

function buildLegal() {
    for (const p of LEGAL) {
        const source = fill(readFileSync(join(here, "legal", p.slug + ".md"), "utf8"))
        const r = render(source)
        const html = r.html.replace(/&lt;mark class=&quot;todo&quot;&gt;(.*?)&lt;\/mark&gt;/g, "<mark class=\"todo\">$1</mark>")
        const other = LEGAL.find(o => o.pair === p.pair && o.lang !== p.lang)
        const switcher = other ? "<p class=\"lang-switch\"><a href=\"" + other.slug + ".html\" hreflang=\"" + other.lang + "\" lang=\"" + other.lang + "\">" + (other.lang === "pl" ? "Wersja polska" : "English version") + "</a></p>" : ""
        const body = "<main id=\"content\" class=\"legal\"><article class=\"prose\">" + switcher + html + "</article></main>"
        write(join(dist, "legal", p.slug + ".html"), page({ base: "../", title: p.title + " · Sylvaris", description: describe(html), body: body, current: "", bodyClass: "legal-page", lang: p.lang }))
    }
}

function buildLanding() {
    const tpl = readFileSync(join(here, "landing.html"), "utf8")
    const parts = PARTS.map(p => "<li><button type=\"button\" class=\"node\" data-part=\"" + p.id + "\" data-group=\"" + p.group + "\" aria-controls=\"part-card\"><span class=\"node-dot\" aria-hidden=\"true\"></span>" + p.name + "</button></li>").join("")
    const data = JSON.stringify(PARTS.map(p => ({ id: p.id, name: p.name, group: p.group, text: p.text, url: urlOf(p.page) })))
    const body = tpl.replace("{{PARTS}}", parts).replace("{{VERSION}}", VERSION).replace(/\{\{REPO\}\}/g, REPO).replace(/\{\{FORUM\}\}/g, FORUM)
    write(join(dist, "index.html"), page({ base: "", title: "Sylvaris · a glass desktop shell for Hyprland, niri and sway", description: "A desktop shell for Hyprland, niri and sway: bar, control center, notifications, launcher, island, lock screen and more, every part optional, all in one warm glass.", body: body, current: "", bodyClass: "home" }))
    write(join(dist, "assets/parts.json"), data)
}

function buildMedia() {
    const out = join(dist, "media")
    mkdirSync(out, { recursive: true })
    let ffmpeg = true
    try {
        execFileSync("ffmpeg", ["-version"], { stdio: "ignore" })
    } catch (e) {
        ffmpeg = false
    }
    for (const gif of readdirSync(join(docs, "demo")).filter(f => f.endsWith(".gif"))) {
        const src = join(docs, "demo", gif)
        const mp4 = join(out, gif.replace(/\.gif$/, ".mp4"))
        const poster = join(out, gif.replace(/\.gif$/, ".jpg"))
        if (!ffmpeg) {
            copyFileSync(src, join(out, gif))
            continue
        }
        if (existsSync(mp4) && statSync(mp4).mtimeMs >= statSync(src).mtimeMs && existsSync(poster))
            continue
        execFileSync("ffmpeg", ["-v", "error", "-y", "-i", src, "-movflags", "+faststart", "-pix_fmt", "yuv420p", "-c:v", "libx264", "-crf", "24", "-preset", "slow", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-an", mp4])
        execFileSync("ffmpeg", ["-v", "error", "-y", "-i", src, "-vf", "thumbnail=90", "-frames:v", "1", "-q:v", "4", poster])
    }
    return ffmpeg
}

function copyAssets() {
    const out = join(dist, "assets")
    mkdirSync(join(out, "fonts"), { recursive: true })
    for (const f of ["site.css", "site.js"])
        copyFileSync(join(here, "assets", f), join(out, f))
    for (const f of readdirSync(join(here, "assets/fonts")))
        copyFileSync(join(here, "assets/fonts", f), join(out, "fonts", f))
    copyFileSync(join(docs, "assets/logo.svg"), join(out, "logo.svg"))
    cpSync(join(docs, "assets"), join(dist, "docs/assets"), { recursive: true })
}

rmSync(join(dist, "docs"), { recursive: true, force: true })
rmSync(join(dist, "legal"), { recursive: true, force: true })
mkdirSync(dist, { recursive: true })
copyAssets()
const index = []
buildDocs(index)
buildLegal()
buildLanding()
write(join(dist, "assets/search.json"), JSON.stringify(index))
const video = process.env.SITE_NO_MEDIA ? true : buildMedia()
write(join(dist, "robots.txt"), "User-agent: *\nAllow: /\n")
write(join(dist, "404.html"), page({ base: "/", title: "Not here · Sylvaris", description: "", current: "", bodyClass: "lost", body: "<main id=\"content\" class=\"lost-main\"><h1>This page drifted off.</h1><p>The address may have changed when the docs were split into pages. The <a href=\"/docs/index.html\">documentation index</a> lists everything, and search (Ctrl K) finds the rest.</p></main>" }))

console.log("built " + relative(process.cwd(), dist) + ": " + index.length + " doc pages, " + LEGAL.length + " legal pages" + (video ? "" : ", demo GIFs copied as-is (ffmpeg not found)"))
if (op.missing.length > 0) {
    console.warn("the legal pages still need: " + op.missing.join(", ") + " (in " + op.file + "; copy site/operator.example.json to site/operator.json)")
    if (strict)
        process.exit(1)
}
