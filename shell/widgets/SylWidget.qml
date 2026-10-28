import QtQuick
import SylStack
import qs.services
import "../lib/widgets.mjs" as Wd

Scope {
    id: root

    readonly property var cfg: Settings.values.widgets
    readonly property bool wanted: false
    readonly property bool windowed: true
    property var screenInfo: null
    property bool editing: false
    property var session: null
    property string selected: ""
    readonly property var items: root.editing && root.session !== null ? root.session.items : root.cfg.items
    readonly property var screens: Stack.screens.map(s => ({
                name: s.name,
                width: s.width,
                height: s.height
            }))
    readonly property string focusedScreen: {
        const w = Compositor.workspaces.find(w => w.focused);
        return w === undefined ? "" : w.output;
    }

    signal opened

    function open(): void {
        Ipc.run(["settings", "open", "widgets"]);
    }

    function close(): void {
        root.done();
    }

    function toggle(): void {
        root.open();
    }

    function toggleOn(screen: var): void {
        root.open();
    }

    function find(id: string): var {
        return root.items.find(i => i.id === id) || null;
    }

    function shownOn(name: string): var {
        if (!root.cfg.enabled)
            return [];
        return root.items.filter(i => !i.inactive && Wd.place(i, root.screens.filter(s => s.name === name), root.cfg.cell, root.cfg.gap) !== null && (i.screen === name || i.screen === "" && root.screens.length > 0 && root.screens[0].name === name)).map(i => i.id);
    }

    function stored(list: var): var {
        return list.map(i => {
            const out = Object.assign({}, i);
            delete out.inactive;
            if (out.children)
                out.children = root.stored(out.children);
            return out;
        });
    }

    function save(list: var): void {
        Settings.set("widgets.items", root.stored(list));
    }

    function change(op: var): void {
        if (root.editing)
            root.session = Wd.apply(root.session, op);
        else
            root.save(Wd.apply(Wd.begin(root.cfg.items), op).items);
    }

    function edit(): void {
        if (root.editing)
            return;
        root.session = Wd.begin(root.cfg.items);
        root.editing = true;
        if (root.selected === "" || root.find(root.selected) === null)
            root.selected = root.cfg.items.length > 0 ? root.cfg.items[0].id : "";
    }

    function done(): void {
        if (!root.editing)
            return;
        const list = Wd.commit(root.session, root.screens, root.cfg.cell, root.cfg.gap);
        root.editing = false;
        root.session = null;
        if (JSON.stringify(root.stored(list)) !== JSON.stringify(root.stored(root.cfg.items)))
            root.save(list);
    }

    function undo(): void {
        if (root.editing)
            root.session = Wd.undo(root.session);
    }

    function add(type: string): string {
        if (Wd.TYPES[type] === undefined)
            throw new Error("unknown widget type " + type + "; pick one of: " + Object.keys(Wd.TYPES).join(", "));
        if (Wd.tooMany(root.items.concat([
            {}
        ])))
            throw new Error("there are already " + Wd.LIMIT + " widgets; remove one first");
        const t = Wd.TYPES[type];
        const id = Wd.newId(root.items.map(i => i.id));
        const item = {
            id: id,
            type: type,
            screen: root.focusedScreen,
            anchor: "top-left",
            col: 0,
            row: 1,
            w: t.size[0],
            h: t.size[1],
            options: {}
        };
        const screen = root.screens.filter(s => s.name === item.screen);
        const placed = Wd.nudge(root.items.concat([item]), screen.length > 0 ? screen[0] : {
            name: item.screen,
            width: 1920,
            height: 1080
        }, root.cfg.cell, root.cfg.gap, root.screens.length > 0 ? root.screens[0].name : "");
        if (root.editing)
            root.session = Wd.apply(root.session, {
                kind: "add",
                item: placed[placed.length - 1]
            });
        else
            root.save(placed);
        root.selected = id;
        return id;
    }

    function remove(id: string): void {
        if (root.find(id) === null)
            throw new Error("no widget with id " + id + "; see sylvaris widgets list");
        root.change({
            kind: "remove",
            id: id
        });
        if (root.selected === id)
            root.selected = "";
    }

    function list(): string {
        return root.items.map(i => i.id + "\t" + i.type + "\t" + (i.screen || "-") + "\t" + i.anchor + " " + i.col + "," + i.row + "\t" + i.w + "x" + i.h + (i.inactive ? "\tinactive" : "")).join("\n");
    }

    function state(): var {
        return {
            enabled: root.cfg.enabled,
            editing: root.editing,
            selected: root.selected,
            items: root.items.map(i => ({
                        id: i.id,
                        type: i.type,
                        screen: i.screen,
                        anchor: i.anchor,
                        col: i.col,
                        row: i.row,
                        w: i.w,
                        h: i.h,
                        layer: i.layer,
                        inactive: i.inactive
                    }))
        };
    }

    Variants {
        model: Stack.screens

        delegate: Scope {
            id: output

            required property var modelData

            Variants {
                model: root.shownOn(output.modelData.name)

                delegate: WidgetWindow {
                    host: root
                    screenData: output.modelData
                }
            }
        }
    }

    Variants {
        model: root.editing ? Stack.screens : []

        delegate: EditCanvas {
            host: root
        }
    }
}
