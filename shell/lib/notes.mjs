export const DEFAULT_NOTES = { wrap: false, lineNumbers: true, highlight: true, tabWidth: 4, spaces: true, size: 14, recent: [] }

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

export function validateNotes(raw) {
    const r = isObject(raw) ? raw : {}
    const d = DEFAULT_NOTES
    return {
        wrap: r.wrap === true,
        lineNumbers: r.lineNumbers !== false,
        highlight: r.highlight !== false,
        tabWidth: Number.isInteger(r.tabWidth) && r.tabWidth >= 1 && r.tabWidth <= 16 ? r.tabWidth : d.tabWidth,
        spaces: r.spaces !== false,
        size: Number.isInteger(r.size) && r.size >= 6 && r.size <= 64 ? r.size : d.size,
        recent: Array.isArray(r.recent) ? r.recent.filter(p => typeof p === "string").slice(0, 10) : []
    }
}

export function detectEol(text) {
    const s = String(text)
    const i = s.indexOf("\n")
    return i > 0 && s.charAt(i - 1) === "\r" ? "crlf" : "lf"
}

export function stripEol(text) {
    return String(text).split("\r\n").join("\n")
}

export function withEol(text, eol) {
    const s = String(text)
    return eol === "crlf" ? s.split("\n").join("\r\n") : s
}

export function isBinary(head) {
    return String(head).slice(0, 8192).indexOf("\u0000") >= 0
}

export function readOnlyFor(bytes) {
    return bytes > 10 * 1024 * 1024
}

export function lossy(text) {
    const s = String(text)
    if (s.indexOf("\ufffd") >= 0)
        return "It is not valid UTF-8 text"
    if (/\r(?!\n)|[\u2028\u2029]/.test(s))
        return "It has line breaks SylNotes would rewrite"
    if (s.indexOf("\r\n") >= 0 && /(^|[^\r])\n/.test(s))
        return "It mixes Windows and Unix line endings"
    return ""
}

export function pushRecent(list, path, max) {
    const cap = max === undefined ? 10 : max
    return [path].concat(list.filter(p => p !== path)).slice(0, cap)
}

export function swapName(path) {
    let h = 0x811c9dc5
    const s = String(path)
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i)
        h = Math.imul(h, 0x01000193) >>> 0
    }
    return ("0000000" + h.toString(16)).slice(-8) + ".swp"
}

export function indentOf(line) {
    return String(line).match(/^[ \t]*/)[0]
}

export function nextIndent(line, tabWidth, spaces) {
    const base = indentOf(line)
    const opens = /[:{[(]\s*$/.test(String(line))
    if (!opens)
        return base
    return base + (spaces ? " ".repeat(tabWidth) : "\t")
}

function escape(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

export function pattern(query, opts) {
    const o = opts || {}
    if (query === "")
        return { re: null, error: "" }
    let src = o.regex ? query : escape(query)
    if (o.wholeWord)
        src = "\\b(?:" + src + ")\\b"
    try {
        return { re: new RegExp(src, o.caseSensitive ? "g" : "gi"), error: "" }
    } catch (e) {
        return { re: null, error: String(e.message || e) }
    }
}

export function findAll(text, query, opts) {
    const p = pattern(query, opts)
    const out = []
    if (p.re === null) {
        out.error = p.error
        return out
    }
    const s = String(text)
    let m
    while ((m = p.re.exec(s)) !== null) {
        if (m[0] === "") {
            p.re.lastIndex++
            continue
        }
        out.push({ start: m.index, end: m.index + m[0].length })
        if (out.length >= 100000)
            break
    }
    out.error = ""
    return out
}

export function replaceAll(text, query, repl, opts) {
    const p = pattern(query, opts)
    if (p.re === null)
        return { text: String(text), count: 0 }
    let count = 0
    const out = String(text).replace(p.re, m => {
        if (m === "")
            return m
        count++
        return opts && opts.regex ? m.replace(new RegExp(p.re.source, p.re.flags.replace("g", "")), repl) : repl
    })
    return { text: out, count: count }
}

export function lineStart(text, line) {
    const s = String(text)
    let at = 0
    for (let i = 1; i < line; i++) {
        const n = s.indexOf("\n", at)
        if (n < 0)
            return s.length
        at = n + 1
    }
    return at
}

export function lineAt(text, offset) {
    return String(text).slice(0, offset).split("\n").length
}

export function lineStarts(text) {
    const s = String(text)
    const out = [0]
    let at = s.indexOf("\n")
    while (at >= 0) {
        out.push(at + 1)
        at = s.indexOf("\n", at + 1)
    }
    return out
}

export function lineOf(starts, offset) {
    let lo = 0
    let hi = starts.length - 1
    while (lo < hi) {
        const mid = (lo + hi + 1) >> 1
        if (starts[mid] <= offset)
            lo = mid
        else
            hi = mid - 1
    }
    return lo + 1
}

export function highlightTheme(c) {
    const style = (color, extra) => Object.assign({ "text-color": color, "selected-text-color": color }, extra || {})
    return {
        metadata: { name: "Sylvaris", revision: 1, license: "MIT" },
        "text-styles": {
            Normal: style(c.text),
            Keyword: style(c.accent, { bold: true }),
            Function: style(c.accentHi),
            Variable: style(c.text),
            ControlFlow: style(c.accent, { bold: true }),
            Operator: style(c.textSoft),
            BuiltIn: style(c.accentHi),
            Extension: style(c.accentHi),
            Preprocessor: style(c.accentDeep),
            Attribute: style(c.accentHi),
            Char: style(c.danger),
            SpecialChar: style(c.danger),
            String: style(c.textSoft, { italic: false }),
            VerbatimString: style(c.textSoft),
            SpecialString: style(c.textSoft),
            Import: style(c.accent),
            DataType: style(c.accentHi),
            DecVal: style(c.danger),
            BaseN: style(c.danger),
            Float: style(c.danger),
            Constant: style(c.danger),
            Comment: style(c.textDim, { italic: true }),
            Documentation: style(c.textDim, { italic: true }),
            Annotation: style(c.textDim),
            CommentVar: style(c.textDim),
            RegionMarker: style(c.textDim),
            Information: style(c.accent),
            Warning: style(c.danger),
            Alert: style(c.danger, { bold: true }),
            Error: style(c.danger, { underline: true }),
            Others: style(c.text)
        },
        "editor-colors": {
            BackgroundColor: c.base,
            TextSelection: c.accentDeep,
            CurrentLine: c.surface,
            LineNumbers: c.textDim,
            CurrentLineNumber: c.text,
            IconBorder: c.base,
            SearchHighlight: c.accent,
            ReplaceHighlight: c.accentHi,
            BracketMatching: c.surface
        }
    }
}

const LANGS = {
    py: "Python", js: "JavaScript", mjs: "JavaScript", cjs: "JavaScript", ts: "TypeScript", tsx: "TypeScript React (TSX)", jsx: "JavaScript React (JSX)",
    qml: "QML", c: "C", h: "C++", cc: "C++", cpp: "C++", hpp: "C++", rs: "Rust", go: "Go", java: "Java", kt: "Kotlin", rb: "Ruby", php: "PHP",
    sh: "Bash", bash: "Bash", zsh: "Zsh", fish: "Fish", nix: "Nix", json: "JSON", toml: "TOML", yaml: "YAML", yml: "YAML", ini: "INI Files",
    conf: "INI Files", md: "Markdown", html: "HTML", css: "CSS", scss: "SCSS", xml: "XML", sql: "SQL", lua: "Lua", cmake: "CMake", diff: "Diff", patch: "Diff"
}

export function languageFor(path) {
    const name = String(path).split("/").pop()
    if (/^(CMakeLists\.txt)$/.test(name))
        return "CMake"
    if (/^(Makefile|makefile|GNUmakefile)$/.test(name))
        return "Makefile"
    const m = name.match(/\.([^.]+)$/)
    return m && LANGS[m[1].toLowerCase()] ? LANGS[m[1].toLowerCase()] : ""
}

export function titleOf(path, n) {
    return path === "" ? "Untitled " + n : String(path).split("/").pop()
}
