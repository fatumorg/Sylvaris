pragma Singleton

import QtQuick
import SylStack
import "../lib/notify.mjs" as N
import "../lib/island.mjs" as I

Singleton {
    id: root

    readonly property bool enabled: Config.values.notifications.server
    readonly property bool dnd: Settings.values.notifications.dnd
    readonly property int timeout: Settings.values.notifications.timeout
    readonly property int cap: Config.values.notifications.history
    readonly property bool island: Settings.values.parts.island
    property var list: []
    property var toasts: []
    property bool centerOpen: false
    property real now: Date.now()
    readonly property int count: root.list.length

    function add(n: var): void {
        n.tracked = true;
        const entry = {
            id: n.id,
            n: n,
            time: Date.now()
        };
        root.list = N.insert(root.list, entry, root.cap);
        n.closed.connect(() => root.forget(entry.id));
        if (root.centerOpen || (root.dnd && n.urgency !== NotificationUrgency.Critical) || (root.island && I.takes(root.facts(n), Settings.values.island, n.urgency === NotificationUrgency.Critical)))
            return;
        root.toasts = N.pushToast(root.toasts, entry.id, 4);
    }

    function facts(n: var): var {
        return {
            appName: n.appName,
            desktopEntry: n.desktopEntry,
            summary: n.summary,
            body: N.plainText(n.body),
            category: n.hints && n.hints.category !== undefined ? String(n.hints.category) : ""
        };
    }

    function entry(id: int): var {
        for (const e of root.list) {
            if (e.id === id)
                return e;
        }
        return null;
    }

    function forget(id: int): void {
        root.list = N.remove(root.list, id);
        root.toasts = root.toasts.filter(t => t !== id);
    }

    function hideToast(id: int): void {
        root.toasts = root.toasts.filter(t => t !== id);
        const e = root.entry(id);
        if (e !== null && e.n.transient)
            root.dismiss(id);
    }

    function dismiss(id: int): void {
        const e = root.entry(id);
        root.forget(id);
        if (e !== null && typeof e.n.dismiss === "function")
            e.n.dismiss();
    }

    function clear(): void {
        for (const e of root.list.slice())
            root.dismiss(e.id);
    }

    function invoke(id: int, action: string): void {
        const e = root.entry(id);
        if (e === null)
            return;
        for (const a of e.n.actions) {
            if (a.identifier === action) {
                a.invoke();
                if (!e.n.resident)
                    root.forget(id);
                return;
            }
        }
        if (action === "default")
            root.hideToast(id);
    }

    function setDnd(v: bool): void {
        Settings.set("notifications.dnd", v);
        if (v)
            root.toasts = root.toasts.filter(t => {
                const e = root.entry(t);
                return e !== null && e.n.urgency === NotificationUrgency.Critical;
            });
    }

    function state(): var {
        return {
            enabled: root.enabled,
            dnd: root.dnd,
            count: root.count,
            toasts: root.toasts,
            items: root.list.map(e => ({
                        id: e.id,
                        app: e.n.appName,
                        icon: e.n.appIcon,
                        image: e.n.image,
                        summary: e.n.summary,
                        body: N.plainText(e.n.body),
                        urgency: e.n.urgency,
                        time: e.time
                    }))
        };
    }

    Timer {
        interval: 30000
        running: root.list.length > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    onCenterOpenChanged: {
        if (root.centerOpen)
            root.toasts = [];
    }

    LazyLoader {
        active: root.enabled

        NotificationServer {
            keepOnReload: true
            persistenceSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            bodyImagesSupported: false
            actionsSupported: true
            imageSupported: true
            inlineReplySupported: true
            onNotification: n => root.add(n)
        }
    }
}
