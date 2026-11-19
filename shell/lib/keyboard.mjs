const SHIFTED = {
    "`": ["~", "grave", "asciitilde"], "1": ["!", "1", "exclam"], "2": ["@", "2", "at"], "3": ["#", "3", "numbersign"],
    "4": ["$", "4", "dollar"], "5": ["%", "5", "percent"], "6": ["^", "6", "asciicircum"], "7": ["&", "7", "ampersand"],
    "8": ["*", "8", "asterisk"], "9": ["(", "9", "parenleft"], "0": [")", "0", "parenright"], "-": ["_", "minus", "underscore"],
    "=": ["+", "equal", "plus"], "[": ["{", "bracketleft", "braceleft"], "]": ["}", "bracketright", "braceright"],
    "\\": ["|", "backslash", "bar"], ";": [":", "semicolon", "colon"], "'": ["\"", "apostrophe", "quotedbl"],
    ",": ["<", "comma", "less"], ".": [">", "period", "greater"], "/": ["?", "slash", "question"]
}

const SYMBOLS = {
    "!": "exclam", "@": "at", "#": "numbersign", "$": "dollar", "%": "percent", "^": "asciicircum", "&": "ampersand",
    "*": "asterisk", "(": "parenleft", ")": "parenright", "-": "minus", "_": "underscore", "=": "equal", "+": "plus",
    "[": "bracketleft", "]": "bracketright", "{": "braceleft", "}": "braceright", ";": "semicolon", ":": "colon",
    "'": "apostrophe", "\"": "quotedbl", ",": "comma", ".": "period", "/": "slash", "?": "question", "\\": "backslash",
    "|": "bar", "`": "grave", "~": "asciitilde", "<": "less", ">": "greater", "€": "EuroSign", "°": "degree"
}

const POLISH = { a: ["ą", "aogonek"], c: ["ć", "cacute"], e: ["ę", "eogonek"], l: ["ł", "lstroke"], n: ["ń", "nacute"], o: ["ó", "oacute"], s: ["ś", "sacute"], x: ["ź", "zacute"], z: ["ż", "zabovedot"] }

function capital(s) {
    return s.charAt(0).toUpperCase() + s.slice(1)
}

function plain(ch, alt) {
    if (SHIFTED[ch] !== undefined) {
        const s = SHIFTED[ch]
        return { label: ch, sym: s[1], shiftLabel: s[0], shiftSym: s[2], width: 1 }
    }
    const k = { label: ch, sym: ch, shiftLabel: ch.toUpperCase(), shiftSym: ch.toUpperCase(), width: 1 }
    if (alt && POLISH[ch] !== undefined) {
        k.altLabel = POLISH[ch][0]
        k.altSym = POLISH[ch][1]
        k.altShiftLabel = POLISH[ch][0].toUpperCase()
        k.altShiftSym = capital(POLISH[ch][1])
    }
    return k
}

function special(label, width, sym, action) {
    const k = { label: label, width: width }
    if (sym !== "")
        k.sym = sym
    if (action !== "")
        k.action = action
    return k
}

function symbol(ch) {
    return { label: ch, sym: SYMBOLS[ch], width: 1.5 }
}

function bottom(polish, pageLabel) {
    const row = [special("Esc", 1.25, "Escape", ""), special("❖", 1.25, "Super_L", ""), special(pageLabel, 1.5, "", "page")]
    if (polish)
        row.push(special("AltGr", 1.25, "", "alt"))
    row.push(special("Space", polish ? 5.75 : 7, "space", ""))
    row.push(special("←", 1, "Left", ""), special("↑", 1, "Up", ""), special("↓", 1, "Down", ""), special("→", 1, "Right", ""))
    return row
}

function letters(polish) {
    const keys = s => s.split("").map(ch => plain(ch, polish))
    return [
        keys("`1234567890-=").concat([special("⌫", 2, "BackSpace", "backspace")]),
        [special("Tab", 1.5, "Tab", "")].concat(keys("qwertyuiop[]"), [special("\\", 1.5, "backslash", "")]),
        [special("Caps", 1.75, "", "caps")].concat(keys("asdfghjkl;'"), [special("Enter", 2.25, "Return", "")]),
        [special("⇧", 2.25, "", "shift")].concat(keys("zxcvbnm,./"), [special("⇧", 2.75, "", "shift")]),
        bottom(polish, "123")
    ]
}

function symbols(polish) {
    const keys = s => s.split("").map(symbol)
    return [
        "1234567890".split("").map(ch => ({ label: ch, sym: ch, width: 1.5 })),
        keys("!@#$%^&*()"),
        keys("-_=+[]{};:"),
        keys("'\",./?\\|~").concat([special("⌫", 1.5, "BackSpace", "backspace")]),
        bottom(polish, "abc")
    ]
}

export const PAGES = ["letters", "symbols"]

export const LAYOUTS = {
    us: { name: "English (US)", letters: letters(false), symbols: symbols(false) },
    pl: { name: "Polish (programmer)", letters: letters(true), symbols: symbols(true) }
}

export function validLayout(id) {
    return typeof id === "string" && Object.prototype.hasOwnProperty.call(LAYOUTS, id)
}

export function rowsFor(id, page) {
    const layout = LAYOUTS[validLayout(id) ? id : "us"]
    return page === "symbols" ? layout.symbols : layout.letters
}

export function symFor(key, shift, alt) {
    if (alt && key.altSym !== undefined)
        return shift ? key.altShiftSym : key.altSym
    return shift && key.shiftSym !== undefined ? key.shiftSym : key.sym
}

export function labelFor(key, shift, alt) {
    if (alt && key.altLabel !== undefined)
        return shift ? key.altShiftLabel : key.altLabel
    return shift && key.shiftLabel !== undefined ? key.shiftLabel : key.label
}

function centre(row, c) {
    let x = 0
    for (let i = 0; i < c; i++)
        x += row[i].width
    return x + row[c].width / 2
}

function nearest(row, x) {
    let best = 0
    let gap = Infinity
    for (let c = 0; c < row.length; c++) {
        const d = Math.abs(centre(row, c) - x)
        if (d < gap) {
            gap = d
            best = c
        }
    }
    return best
}

export function move(rows, r, c, dir) {
    const n = rows[r].length
    if (dir === "right")
        return { r: r, c: (c + 1) % n }
    if (dir === "left")
        return { r: r, c: (c + n - 1) % n }
    if (dir !== "up" && dir !== "down")
        return { r: r, c: c }
    const to = (r + (dir === "down" ? 1 : rows.length - 1)) % rows.length
    return { r: to, c: nearest(rows[to], centre(rows[r], c)) }
}

export const DEFAULT_KEYBOARD = { layout: "us", size: 1, gamepad: true, combo: true }

export function validateKeyboard(raw) {
    const v = raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    return Object.assign({}, v, {
        layout: validLayout(v.layout) ? v.layout : DEFAULT_KEYBOARD.layout,
        size: typeof v.size === "number" && v.size >= 0.6 && v.size <= 1.6 ? v.size : DEFAULT_KEYBOARD.size,
        gamepad: typeof v.gamepad === "boolean" ? v.gamepad : DEFAULT_KEYBOARD.gamepad,
        combo: typeof v.combo === "boolean" ? v.combo : DEFAULT_KEYBOARD.combo
    })
}

const TEXTLESS = ["Escape", "Super_L", "Tab", "Return", "BackSpace", "Left", "Up", "Down", "Right"]

export function textFor(key, shift, alt) {
    if (key === null || key === undefined || key.sym === undefined || TEXTLESS.indexOf(key.sym) >= 0)
        return ""
    if (key.sym === "space")
        return " "
    return labelFor(key, shift, alt)
}
