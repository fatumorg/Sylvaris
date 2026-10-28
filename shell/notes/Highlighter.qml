import QtQuick
import org.kde.syntaxhighlighting

SyntaxHighlighter {
    id: hl

    property var ed: null
    readonly property string detected: hl.ed === null ? "" : Repository.definitionForFileName(hl.ed.path).name
    readonly property string current: hl.ed === null ? "" : hl.ed.chosen !== "" ? hl.ed.chosen : hl.detected
    readonly property var names: Repository.definitions.map(d => d.name).sort((a, b) => a.localeCompare(b))
    readonly property bool own: hl.ed !== null && hl.ed.notes.themeBaked === hl.ed.notes.themeJson && Repository.themes.some(t => t.name === "Sylvaris")

    textEdit: hl.ed === null ? null : hl.ed.edit
    definition: hl.current
    theme: hl.own ? "Sylvaris" : Repository.defaultTheme(hl.ed !== null && hl.ed.notes.dark ? Repository.DarkTheme : Repository.LightTheme)
}
