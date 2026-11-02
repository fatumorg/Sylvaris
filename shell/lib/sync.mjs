export const TARGETS = [
    { id: "gtk", label: "GTK apps", about: "GTK 3 and 4 apps, and Chrome, Brave or Vivaldi set to their GTK theme" },
    { id: "qt", label: "Qt apps", about: "Pick “sylvaris” in qt5ct or qt6ct once" },
    { id: "kitty", label: "kitty", about: "Updates open terminals right away" },
    { id: "foot", label: "foot", about: "New foot windows" },
    { id: "vscode", label: "VS Code, VSCodium and Cursor", about: "Recolours the editor live through its settings.json" },
    { id: "zed", label: "Zed", about: "Pick the Sylvaris theme once" },
    { id: "neovim", label: "Neovim and Vim", about: "Use “colorscheme sylvaris”" },
    { id: "firefox", label: "Firefox, LibreWolf and Mullvad Browser", about: "Colours the browser frame through userChrome.css after a browser restart" },
    { id: "zen", label: "Zen Browser", about: "Colours Zen's frame and spaces through userChrome.css after a browser restart" }
]

const BROWSERS = ["firefox", "zen"]

function defaults() {
    const out = {}
    for (const t of TARGETS)
        out[t.id] = BROWSERS.indexOf(t.id) < 0
    return out
}

export const DEFAULT_SYNC = { enabled: false, targets: defaults() }

export function validateSync(raw) {
    const v = raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    const src = v.targets !== null && typeof v.targets === "object" ? v.targets : {}
    const targets = {}
    for (const t of TARGETS)
        targets[t.id] = typeof src[t.id] === "boolean" ? src[t.id] : t.id === "zen" && typeof src.firefox === "boolean" ? src.firefox : DEFAULT_SYNC.targets[t.id]
    return Object.assign({}, v, { enabled: v.enabled === true, targets: targets })
}

function rgb(hex) {
    const h = hex.replace("#", "").slice(-6)
    return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16) / 255)
}

function hex(r, g, b) {
    return "#" + [r, g, b].map(v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")).join("")
}

function toHsl(c) {
    const [r, g, b] = rgb(c)
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    const l = (max + min) / 2
    if (max === min)
        return [0, 0, l]
    const d = max - min
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    const h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4
    return [h * 60, s, l]
}

function fromHsl(h, s, l) {
    const k = n => (n + h / 30) % 12
    const a = s * Math.min(l, 1 - l)
    const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)))
    return hex(f(0), f(8), f(4))
}

function mix(a, b, t) {
    const x = rgb(a), y = rgb(b)
    return hex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t)
}

export function palette(c) {
    const clean = k => "#" + c[k].replace("#", "").slice(-6).toLowerCase()
    return {
        bg: clean("base"), bg2: clean("surface"), fg: clean("text"), dim: clean("textDim"), soft: clean("textSoft"),
        accent: clean("accent"), hi: clean("accentHi"), deep: clean("accentDeep"), onAccent: clean("onAccent"), red: clean("danger")
    }
}

export function ansi(p) {
    const s = Math.max(0.38, Math.min(0.6, toHsl(p.accent)[1]))
    const l = Math.max(0.55, Math.min(0.66, toHsl(p.accent)[2] + 0.08))
    const hue = h => fromHsl(h, s, l)
    const bright = h => fromHsl(h, s, Math.min(0.8, l + 0.1))
    const normal = [p.bg, p.red, hue(95), hue(42), hue(212), hue(300), hue(178), p.soft]
    const light = [mix(p.bg, p.dim, 0.6), mix(p.red, "#ffffff", 0.18), bright(95), bright(42), bright(212), bright(300), bright(178), p.fg]
    return normal.concat(light)
}

export function gtkCss(p) {
    const pairs = [["accent_color", p.hi], ["accent_bg_color", p.accent], ["accent_fg_color", p.onAccent], ["window_bg_color", p.bg], ["window_fg_color", p.fg], ["view_bg_color", p.bg], ["view_fg_color", p.fg], ["headerbar_bg_color", p.bg2], ["headerbar_fg_color", p.fg], ["card_bg_color", p.bg2], ["card_fg_color", p.fg], ["popover_bg_color", p.bg2], ["popover_fg_color", p.fg], ["dialog_bg_color", p.bg2], ["dialog_fg_color", p.fg], ["sidebar_bg_color", p.bg2], ["sidebar_fg_color", p.fg], ["destructive_bg_color", p.red], ["theme_bg_color", p.bg], ["theme_fg_color", p.fg], ["theme_base_color", p.bg], ["theme_text_color", p.fg], ["theme_selected_bg_color", p.accent], ["theme_selected_fg_color", p.onAccent]]
    return pairs.map(([k, v]) => "@define-color " + k + " " + v + ";").join("\n") + "\n"
}

export function kittyConf(p) {
    const a = ansi(p)
    return ["foreground " + p.fg, "background " + p.bg, "selection_foreground " + p.onAccent, "selection_background " + p.accent, "cursor " + p.hi, "cursor_text_color " + p.bg, "url_color " + p.hi, "active_border_color " + p.accent, "inactive_border_color " + p.bg2, "active_tab_foreground " + p.onAccent, "active_tab_background " + p.accent, "inactive_tab_foreground " + p.dim, "inactive_tab_background " + p.bg2]
        .concat(a.map((c, i) => "color" + i + " " + c)).join("\n") + "\n"
}

export function footIni(p) {
    const a = ansi(p).map(c => c.slice(1))
    return ["[colors]", "foreground=" + p.fg.slice(1), "background=" + p.bg.slice(1), "selection-foreground=" + p.onAccent.slice(1), "selection-background=" + p.accent.slice(1)]
        .concat(a.slice(0, 8).map((c, i) => "regular" + i + "=" + c)).concat(a.slice(8).map((c, i) => "bright" + i + "=" + c)).join("\n") + "\n"
}

export function qtColors(p) {
    const argb = c => "#ff" + c.slice(1)
    const roles = [p.fg, p.bg2, mix(p.bg2, "#ffffff", 0.12), mix(p.bg2, "#ffffff", 0.06), mix(p.bg, "#000000", 0.3), mix(p.bg, p.bg2, 0.5), p.fg, "#ffffff", p.fg, p.bg, p.bg, "#000000", p.accent, p.onAccent, p.hi, p.deep, p.bg2, "#000000", p.bg2, p.fg, p.dim].map(argb).join(", ")
    const off = [p.dim, p.bg2, mix(p.bg2, "#ffffff", 0.12), mix(p.bg2, "#ffffff", 0.06), mix(p.bg, "#000000", 0.3), mix(p.bg, p.bg2, 0.5), p.dim, "#ffffff", p.dim, p.bg, p.bg, "#000000", p.deep, p.onAccent, p.hi, p.deep, p.bg2, "#000000", p.bg2, p.fg, p.dim].map(argb).join(", ")
    return "[ColorScheme]\nactive_colors=" + roles + "\ndisabled_colors=" + off + "\ninactive_colors=" + roles + "\n"
}

export function vscodeTheme(p) {
    const a = ansi(p)
    const colors = {
        "editor.background": p.bg, "editor.foreground": p.fg, "editorLineNumber.foreground": p.dim, "editorLineNumber.activeForeground": p.hi,
        "editor.selectionBackground": p.deep + "80", "editorCursor.foreground": p.hi, "sideBar.background": p.bg2, "sideBar.foreground": p.soft,
        "activityBar.background": p.bg2, "activityBar.foreground": p.fg, "activityBarBadge.background": p.accent, "activityBarBadge.foreground": p.onAccent,
        "titleBar.activeBackground": p.bg2, "titleBar.activeForeground": p.fg, "statusBar.background": p.bg2, "statusBar.foreground": p.soft,
        "tab.activeBackground": p.bg, "tab.inactiveBackground": p.bg2, "tab.activeBorderTop": p.accent, "panel.background": p.bg,
        "button.background": p.accent, "button.foreground": p.onAccent, "focusBorder": p.accent, "list.activeSelectionBackground": p.deep,
        "list.activeSelectionForeground": p.fg, "input.background": p.bg2, "terminal.background": p.bg, "terminal.foreground": p.fg
    }
    const names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
    names.forEach((n, i) => {
        colors["terminal.ansi" + n] = a[i]
        colors["terminal.ansiBright" + n] = a[i + 8]
    })
    const tokenColors = [
        { scope: ["comment"], settings: { foreground: p.dim, fontStyle: "italic" } },
        { scope: ["keyword", "storage"], settings: { foreground: p.accent } },
        { scope: ["string"], settings: { foreground: a[2] } },
        { scope: ["constant", "constant.numeric"], settings: { foreground: a[3] } },
        { scope: ["entity.name.function", "support.function"], settings: { foreground: a[4] } },
        { scope: ["entity.name.type", "support.type"], settings: { foreground: a[6] } },
        { scope: ["variable"], settings: { foreground: p.fg } }
    ]
    return { colors: colors, tokenColors: tokenColors }
}

export function zedTheme(p) {
    const a = ansi(p)
    const o = c => c + "ff"
    const style = {
        background: o(p.bg), "editor.background": o(p.bg), "editor.foreground": o(p.fg), "panel.background": o(p.bg2), "status_bar.background": o(p.bg2),
        "title_bar.background": o(p.bg2), "tab_bar.background": o(p.bg2), "tab.active_background": o(p.bg), "tab.inactive_background": o(p.bg2),
        text: o(p.fg), "text.muted": o(p.dim), "text.accent": o(p.hi), border: o(p.bg2), "element.selected": o(p.deep), "editor.line_number": o(p.dim),
        "editor.active_line_number": o(p.hi), "terminal.background": o(p.bg), "terminal.foreground": o(p.fg),
        players: [{ cursor: o(p.hi), selection: p.deep + "80", background: o(p.accent) }],
        syntax: { comment: { color: o(p.dim), font_style: "italic" }, keyword: { color: o(p.accent) }, string: { color: o(a[2]) }, number: { color: o(a[3]) }, function: { color: o(a[4]) }, type: { color: o(a[6]) } }
    }
    return JSON.stringify({ "$schema": "https://zed.dev/schema/themes/v0.2.0.json", name: "Sylvaris", author: "Sylvaris", themes: [{ name: "Sylvaris", appearance: "dark", style: style }] }, null, 2)
}

export function nvimLua(p) {
    const a = ansi(p)
    const hl = (g, fg, bg, extra) => "hi(\"" + g + "\", { fg = \"" + fg + "\"" + (bg ? ", bg = \"" + bg + "\"" : "") + (extra || "") + " })"
    return ["vim.cmd(\"hi clear\")", "vim.o.background = \"dark\"", "vim.g.colors_name = \"sylvaris\"", "local hi = function(g, o) vim.api.nvim_set_hl(0, g, o) end",
        hl("Normal", p.fg, p.bg), hl("NormalFloat", p.fg, p.bg2), hl("LineNr", p.dim), hl("CursorLineNr", p.hi), hl("Visual", p.fg, p.deep), hl("Comment", p.dim, null, ", italic = true"),
        hl("Keyword", p.accent), hl("Statement", p.accent), hl("String", a[2]), hl("Number", a[3]), hl("Constant", a[3]), hl("Function", a[4]), hl("Type", a[6]),
        hl("Pmenu", p.fg, p.bg2), hl("PmenuSel", p.onAccent, p.accent), hl("StatusLine", p.fg, p.bg2), hl("Search", p.onAccent, p.hi), hl("Error", p.red)
    ].concat(a.map((c, i) => "vim.g.terminal_color_" + i + " = \"" + c + "\"")).join("\n") + "\n"
}

export function vimColors(p) {
    const a = ansi(p)
    const hl = (g, fg, bg) => "hi " + g + " guifg=" + fg + (bg ? " guibg=" + bg : "")
    return ["hi clear", "set background=dark", "let g:colors_name = \"sylvaris\"", hl("Normal", p.fg, p.bg), hl("LineNr", p.dim), hl("CursorLineNr", p.hi), hl("Visual", p.fg, p.deep), hl("Comment", p.dim),
        hl("Statement", p.accent), hl("String", a[2]), hl("Constant", a[3]), hl("Function", a[4]), hl("Type", a[6]), hl("Pmenu", p.fg, p.bg2), hl("PmenuSel", p.onAccent, p.accent), hl("StatusLine", p.fg, p.bg2)].join("\n") + "\n"
}

export function firefoxCss(p) {
    const vars = {
        "--lwt-accent-color": p.bg, "--lwt-accent-color-inactive": p.bg, "--lwt-text-color": p.fg,
        "--toolbox-bgcolor": p.bg, "--toolbox-bgcolor-inactive": p.bg, "--toolbox-textcolor": p.fg, "--toolbox-textcolor-inactive": p.soft,
        "--toolbar-bgcolor": p.bg2, "--toolbar-color": p.fg, "--toolbarbutton-icon-fill": p.fg,
        "--toolbarbutton-hover-background": mix(p.bg2, p.fg, 0.12), "--toolbarbutton-active-background": mix(p.bg2, p.fg, 0.2),
        "--toolbar-field-background-color": p.bg, "--toolbar-field-color": p.fg, "--toolbar-field-border-color": mix(p.bg, p.fg, 0.12),
        "--toolbar-field-focus-background-color": p.bg, "--toolbar-field-focus-color": p.fg, "--toolbar-field-focus-border-color": p.accent,
        "--tab-selected-bgcolor": p.bg2, "--tab-selected-textcolor": p.fg, "--tab-hover-background-color": mix(p.bg, p.fg, 0.08),
        "--tab-loading-fill": p.accent, "--tab-attention-icon-color": p.accent,
        "--arrowpanel-background": p.bg2, "--arrowpanel-color": p.fg, "--arrowpanel-border-color": mix(p.bg2, p.fg, 0.12),
        "--panel-separator-color": mix(p.bg2, p.fg, 0.12), "--urlbarView-highlight-background": p.accent, "--urlbarView-highlight-color": p.onAccent,
        "--urlbarView-hover-background": mix(p.bg2, p.fg, 0.1), "--sidebar-background-color": p.bg2, "--sidebar-text-color": p.fg,
        "--sidebar-border-color": mix(p.bg2, p.fg, 0.12), "--button-bgcolor": mix(p.bg2, p.fg, 0.08), "--button-hover-bgcolor": mix(p.bg2, p.fg, 0.14),
        "--button-primary-bgcolor": p.accent, "--button-primary-color": p.onAccent, "--focus-outline-color": p.accent,
        "--color-accent-primary": p.accent, "--link-color": p.hi, "--in-content-page-background": p.bg
    }
    const root = Object.keys(vars).map(k => "  " + k + ": " + vars[k] + " !important;")
    const rule = (sel, body) => [sel + " {"].concat(body.map(b => "  " + b + " !important;"), ["}"])
    return [":root, :root:-moz-lwtheme {"].concat(root, ["}"],
        rule("#navigator-toolbox, #TabsToolbar, #titlebar, #toolbar-menubar", ["background-color: " + p.bg, "color: " + p.fg, "border-color: transparent"]),
        rule("#nav-bar, #PersonalToolbar, #sidebar-box, #sidebar-header, #sidebar-main, #sidebar", ["background-color: " + p.bg2, "color: " + p.fg]),
        rule(".tab-background[selected]", ["background-color: " + p.bg2, "background-image: none"]),
        rule(".tab-background[selected], .tab-background:is([multiselected])", ["outline-color: " + p.accent]),
        rule("#urlbar-background, #searchbar", ["background-color: " + p.bg, "border-color: " + mix(p.bg, p.fg, 0.12)]),
        rule("#urlbar[focused] #urlbar-background, #urlbar[open] #urlbar-background, #searchbar:focus-within", ["background-color: " + p.bg, "border-color: " + p.accent]),
        rule("#urlbar-input, #urlbar, .urlbarView-title, .urlbarView-url", ["color: " + p.fg]),
        rule("menupopup, panel, .panel-arrowcontent, .menupopup-arrowscrollbox", ["--panel-background: " + p.bg2, "--panel-color: " + p.fg, "--panel-border-color: " + mix(p.bg2, p.fg, 0.12), "color: " + p.fg]),
        rule("menu:where([_moz-menuactive]:not([disabled])), menuitem:where([_moz-menuactive]:not([disabled]))", ["background-color: " + p.accent, "color: " + p.onAccent]),
        rule("#statuspanel-label", ["background-color: " + p.bg2, "color: " + p.fg, "border-color: " + mix(p.bg2, p.fg, 0.12)]),
        rule("::selection", ["background-color: " + p.accent, "color: " + p.onAccent]),
        [""]).join("\n")
}

export function zenCss(p) {
    const vars = {
        "--zen-main-browser-background": p.bg, "--zen-main-browser-background-toolbar": p.bg, "--zen-main-browser-background-old": p.bg,
        "--zen-main-browser-background-toolbar-old": p.bg, "--zen-themed-toolbar-bg": p.bg, "--zen-themed-toolbar-bg-transparent": p.bg,
        "--zen-primary-color": p.accent, "--zen-colors-primary": mix(p.bg2, p.accent, 0.25), "--zen-colors-secondary": mix(p.bg2, p.accent, 0.12),
        "--zen-colors-tertiary": p.bg2, "--zen-colors-hover-bg": mix(p.bg2, p.fg, 0.1), "--zen-colors-primary-foreground": p.fg,
        "--zen-colors-border": mix(p.bg2, p.fg, 0.12), "--zen-colors-border-contrast": mix(p.bg2, p.fg, 0.2), "--zen-colors-input-bg": p.bg,
        "--zen-dialog-background": p.bg2, "--zen-urlbar-background": p.bg2, "--zen-urlbar-background-base": p.bg2,
        "--zen-accent-button-background": p.accent, "--zen-accent-button-color": p.onAccent, "--zen-grainy-background-opacity": "0"
    }
    return firefoxCss(p) + [":root, :root:-moz-lwtheme {"].concat(Object.keys(vars).map(k => "  " + k + ": " + vars[k] + " !important;"), ["}", ""]).join("\n")
}

export function firefoxContentCss(p) {
    const pages = ["about:newtab", "about:home", "about:blank", "about:privatebrowsing", "about:preferences", "about:addons", "about:config"].map(u => "url-prefix(\"" + u + "\")").join(", ")
    return ["@-moz-document " + pages + " {", "  :root, body {", "    --newtab-background-color: " + p.bg + " !important;", "    --newtab-background-color-secondary: " + p.bg2 + " !important;",
        "    --newtab-text-primary-color: " + p.fg + " !important;", "    --in-content-page-background: " + p.bg + " !important;", "    --in-content-page-color: " + p.fg + " !important;",
        "    --in-content-box-background: " + p.bg2 + " !important;", "    --in-content-primary-button-background: " + p.accent + " !important;",
        "    --in-content-primary-button-text-color: " + p.onAccent + " !important;", "    --in-content-accent-color: " + p.accent + " !important;",
        "    --color-accent-primary: " + p.accent + " !important;", "    background-color: " + p.bg + " !important;", "    color: " + p.fg + " !important;", "  }", "}", ""].join("\n")
}

export function plan(p, targets, configHome, home) {
    const ops = []
    let target = ""
    const write = (path, content, needs) => ops.push({ op: "write", target: target, path: path, content: content, needs: needs })
    const line = (path, text, needs) => ops.push({ op: "line", target: target, path: path, line: text, needs: needs })
    target = "gtk"
    if (targets.gtk)
        for (const v of ["gtk-3.0", "gtk-4.0"]) {
            write(configHome + "/" + v + "/sylvaris.css", gtkCss(p), configHome)
            line(configHome + "/" + v + "/gtk.css", "@import 'sylvaris.css';", configHome)
        }
    target = "qt"
    if (targets.qt)
        for (const v of ["qt5ct", "qt6ct"])
            write(configHome + "/" + v + "/colors/sylvaris.conf", qtColors(p), configHome + "/" + v)
    target = "kitty"
    if (targets.kitty) {
        write(configHome + "/kitty/sylvaris.conf", kittyConf(p), configHome + "/kitty")
        line(configHome + "/kitty/kitty.conf", "include sylvaris.conf", configHome + "/kitty")
        ops.push({ op: "run", target: target, argv: ["pkill", "-USR1", "-x", "kitty"], needs: configHome + "/kitty" })
    }
    target = "foot"
    if (targets.foot) {
        write(configHome + "/foot/sylvaris.ini", footIni(p), configHome + "/foot")
        line(configHome + "/foot/foot.ini", "include=" + configHome + "/foot/sylvaris.ini", configHome + "/foot")
    }
    target = "vscode"
    if (targets.vscode) {
        const code = vscodeTheme(p)
        ops.push({ op: "vscode", target: target, colors: code.colors, tokenColors: code.tokenColors, dirs: ["Code", "VSCodium", "Cursor", "Code - OSS"].map(n => configHome + "/" + n + "/User") })
    }
    target = "zed"
    if (targets.zed)
        write(configHome + "/zed/themes/sylvaris.json", zedTheme(p), configHome + "/zed")
    target = "neovim"
    if (targets.neovim) {
        write(configHome + "/nvim/colors/sylvaris.lua", nvimLua(p), configHome + "/nvim")
        write(home + "/.vim/colors/sylvaris.vim", vimColors(p), home + "/.vim")
    }
    target = "firefox"
    if (targets.firefox)
        ops.push({ op: "firefox", target: target, content: firefoxCss(p), contentCss: firefoxContentCss(p), roots: [configHome + "/mozilla/firefox", home + "/.mozilla/firefox", home + "/.librewolf", home + "/.mullvad-browser/Browser/TorBrowser/Data/Browser"] })
    target = "zen"
    if (targets.zen)
        ops.push({ op: "firefox", target: target, content: zenCss(p), contentCss: firefoxContentCss(p), roots: [configHome + "/zen", home + "/.zen"] })
    return ops
}

export function summary(results, id) {
    const mine = results.filter(r => r.target === id)
    if (mine.length === 0)
        return ""
    const bad = mine.find(r => r.status.indexOf("failed") === 0 || r.status.indexOf("add this line") === 0)
    if (bad)
        return bad.status.charAt(0).toUpperCase() + bad.status.slice(1)
    if (mine.every(r => r.status.indexOf("skipped") === 0))
        return "Not installed"
    return "Up to date"
}
