import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/access.mjs" as A

Popup {
    id: root

    readonly property var cfg: Settings.values.access
    readonly property var can: A.supports(Compositor.name)
    readonly property string shaderDir: Qt.resolvedUrl("../assets/shaders").toString().replace("file://", "")
    property bool started: false
    property var tools: ({})
    property var applied: []
    property real quietUntil: 0
    readonly property string tintPath: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/night.frag"

    namespace: "sylaccess"
    corner: root.local.placement.access
    panelWidth: Tokens.accessWidth
    panelHeight: Tokens.accessHeight

    function apply(): void {
        if (Demo.enabled || Compositor.name !== "hyprland")
            return;
        const tint = NightLight.tint;
        const cmds = A.hyprCommands(Compositor.usingLua, root.cfg, root.shaderDir, tint === null ? "" : root.tintPath);
        root.applied = cmds;
        root.quietUntil = Date.now() + 2000;
        Stack.execDetached(["hyprctl"].concat(cmds[0]));
        if (tint === null)
            Stack.execDetached(["hyprctl"].concat(cmds[1]));
        else {
            filterSource.path = root.cfg.filter === "none" ? "" : root.shaderDir + "/" + root.cfg.filter + ".frag";
            Stack.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1.part\" && mv -f \"$1.part\" \"$1\" && shift 2 && exec hyprctl \"$@\"", "sh", root.tintPath, A.tintShader(root.cfg.filter === "none" ? "" : filterSource.text(), tint)].concat(cmds[1]));
        }
        if (root.cfg.cursor > 0)
            Stack.execDetached(["hyprctl", "setcursor", Stack.env("XCURSOR_THEME") || "default", String(root.cfg.cursor)]);
    }

    function zoom(value: string): void {
        const now = root.cfg.zoom;
        const next = value === "in" ? now + 0.5 : value === "out" ? now - 0.5 : Number(value);
        if (!(next >= 1 && next <= 5) && value !== "in" && value !== "out")
            throw new Error("usage: access zoom <in|out|1..5>");
        Settings.set("access.zoom", Math.max(1, Math.min(5, Math.round(next * 10) / 10)));
    }

    function filter(name: string): void {
        if (A.FILTERS.indexOf(name) < 0)
            throw new Error("usage: access filter <" + A.FILTERS.join("|") + ">");
        Settings.set("access.filter", name);
    }

    function toggleTool(bin: string, args: var): void {
        if (!root.tools[bin])
            return;
        Stack.execDetached(["sh", "-c", "pkill -x \"$0\" || exec \"$@\"", bin].concat([bin]).concat(args));
    }

    function state(): var {
        return Object.assign({
            open: root.shown,
            compositor: Compositor.name,
            applied: root.applied,
            tools: root.tools
        }, root.cfg);
    }

    onCfgChanged: {
        if (root.started)
            root.apply();
    }

    Component.onCompleted: {
        root.started = true;
        NightLight.shaderOwner = true;
        if (root.cfg.zoom !== 1 || root.cfg.filter !== "none" || root.cfg.cursor > 0 || NightLight.tint !== null)
            root.apply();
    }

    Component.onDestruction: NightLight.shaderOwner = false

    Connections {
        target: NightLight
        function onTintChanged() {
            if (root.started)
                root.apply();
        }
    }

    FileView {
        id: filterSource
        blockLoading: true
        printErrors: false
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            if (event.name === "configreloaded" && Date.now() >= root.quietUntil)
                root.apply();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "for t in orca wvkbd-mobintl; do command -v $t >/dev/null 2>&1 && echo $t; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const t of text.split("\n").filter(Boolean))
                    out[t] = true;
                root.tools = out;
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: page.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        AccessPage {
            id: page
            width: parent.width
            access: root
        }
    }
}
