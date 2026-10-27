pragma Singleton

import QtQuick
import SylStack
import "../lib/pad.mjs" as P

Singleton {
    id: root

    readonly property var list: Demo.enabled ? Demo.apps : P.visible(DesktopEntries.applications.values)
    property string lastLaunched: ""

    function byId(id: string): var {
        for (const a of root.list) {
            if (a.id === id)
                return a;
        }
        return null;
    }

    function entry(id: string): var {
        if (!id || DesktopEntries.applications.values.length === 0)
            return null;
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
    }

    function icon(app: var): string {
        return app && app.icon ? Stack.iconPath(app.icon, true) : "";
    }

    function launch(app: var): void {
        if (!app)
            return;
        root.lastLaunched = app.id;
        if (Demo.enabled)
            return;
        if (app.runInTerminal)
            Stack.execDetached([Config.values.terminal, "-e"].concat(app.command));
        else
            app.execute();
    }
}
