import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.center
import qs.theme
import qs.clock
import qs.notify
import qs.pad
import qs.bar
import qs.deck
import qs.media
import qs.settings
import qs.power
import qs.paper
import qs.plugins.diver
import qs.plugins.fatest
import qs.plugins.rgb
import qs.switcher
import qs.lock
import qs.polkit
import qs.clip
import qs.viewer
import qs.files
import qs.archive
import qs.island
import qs.capture
import qs.access
import qs.plugins
import qs.sync
import "lib/ipc.mjs" as I
import "lib/eq.mjs" as E
import "lib/settings.mjs" as S
import "lib/modules.mjs" as M

ShellRoot {
    id: root

    readonly property bool ready: Config.ready && Settings.ready
    readonly property var live: root.ready ? S.liveParts(Settings.values.parts, Settings.values.plugins).concat(S.liveServices(Settings.values.parts, Settings.values.plugins)) : []
    readonly property var loaders: ({
            center: centerLoader,
            theme: themeLoader,
            clock: clockLoader,
            notify: notifyLoader,
            pad: padLoader,
            media: mediaLoader,
            settings: settingsLoader,
            power: powerLoader,
            paper: paperLoader,
            diver: diverLoader,
            fatest: fatestLoader,
            rgb: rgbLoader,
            switcher: switcherLoader,
            lock: lockLoader,
            polkit: polkitLoader,
            clip: clipLoader,
            island: islandLoader,
            capture: captureLoader,
            viewer: viewerLoader,
            files: filesLoader,
            archive: archiveLoader,
            access: accessLoader,
            plugins: pluginsLoader,
            sync: syncLoader
        })
    readonly property var parts: {
        const out = {};
        for (const name of Object.keys(root.loaders)) {
            if (root.loaders[name].item)
                out[name] = root.loaders[name].item;
        }
        return out;
    }
    readonly property var services: ({
            Sky: () => Sky,
            Weather: () => Weather,
            Diver: () => Diver,
            Notifications: () => Notifications,
            Apps: () => Apps,
            Equalizer: () => Equalizer,
            Headphones: () => Headphones,
            ThemePreview: () => ThemePreview,
            Audio: () => Audio,
            Media: () => Media,
            NightLight: () => NightLight,
            Dnd: () => Dnd,
            Toggles: () => Toggles,
            BluetoothService: () => BluetoothService,
            NetworkService: () => NetworkService,
            Hotspot: () => Hotspot,
            Displays: () => Displays,
            Plugins: () => Plugins,
            Sync: () => Sync
        })
    readonly property var boot: [Tokens, Ipc, Config, Settings, Theme, Resin, Compositor, Keybinds].concat(root.live.filter(name => root.services[name] !== undefined).map(name => root.services[name]()))

    readonly property var openPanel: {
        for (const name of ["center", "clock", "media", "notify", "paper", "clip", "capture", "access", "diver", "fatest", "rgb"]) {
            const p = root.part(name);
            if (p !== null && p.wanted && p.screenInfo && p.placed !== undefined)
                return {
                    corner: p.placed,
                    docked: p.from !== undefined && p.from !== "",
                    width: p.panelWidth,
                    height: p.panelHeight,
                    screen: p.screenInfo.name
                };
        }
        return null;
    }

    function on(name: string): bool {
        return root.live.indexOf(name) >= 0;
    }

    function need(name: string): var {
        const p = root.part(name);
        if (p === null)
            throw new Error(name + " is excluded by the parts setting; turn it back on with: sylvaris set parts." + name + " true");
        return p;
    }

    function solo(keep: var): void {
        for (const name of Object.keys(root.parts)) {
            if (root.parts[name] !== keep && root.parts[name].windowed !== true)
                root.parts[name].close();
        }
    }

    function openOn(name: string, arg: string, screen: var): void {
        const p = root.part(name);
        if (p === null)
            return;
        if (name === "center")
            p.toggleOn(screen, arg);
        else
            p.toggleOn(screen);
    }

    function screenOf(p: var): var {
        return p !== null && p.wanted && p.screenInfo ? p.screenInfo.name : null;
    }

    function part(name: string): var {
        return root.parts[name] === undefined ? null : root.parts[name];
    }

    function stateObject(): var {
        const center = root.part("center");
        const clock = root.part("clock");
        const settings = root.part("settings");
        const pad = root.part("pad");
        const theme = root.part("theme");
        const out = {
            version: 1,
            compositor: Compositor.state(),
            audio: root.on("Audio") ? {
                available: Audio.available,
                volume: Audio.volume,
                muted: Audio.muted,
                output: Audio.outputName,
                sinks: Audio.sinks
            } : undefined,
            media: root.on("Media") ? Media.state() : undefined,
            eq: root.on("Equalizer") ? Object.assign({
                running: Equalizer.running,
                target: Equalizer.target
            }, Equalizer.cfg) : undefined,
            headphones: root.on("Headphones") ? Headphones.state() : undefined,
            nightLight: root.on("NightLight") ? {
                available: NightLight.available,
                enabled: NightLight.enabled,
                temperature: NightLight.temperature,
                error: NightLight.error
            } : undefined,
            dnd: root.on("Dnd") ? {
                available: Dnd.available,
                tool: Dnd.tool,
                enabled: Dnd.enabled
            } : undefined,
            toggles: root.on("Toggles") ? Toggles.items : undefined,
            bluetooth: root.on("BluetoothService") ? {
                available: BluetoothService.available,
                enabled: BluetoothService.enabled,
                scanning: BluetoothService.scanning,
                summary: BluetoothService.summary,
                items: BluetoothService.items,
                error: BluetoothService.error
            } : undefined,
            network: root.on("NetworkService") ? {
                available: NetworkService.available,
                hasWifi: NetworkService.hasWifi,
                enabled: NetworkService.enabled,
                summary: NetworkService.summary,
                items: NetworkService.items,
                error: NetworkService.error
            } : undefined,
            hotspot: root.on("Hotspot") ? {
                available: Hotspot.available,
                active: Hotspot.active,
                profileExists: Hotspot.profileExists,
                error: Hotspot.error
            } : undefined,
            displays: root.on("Displays") ? {
                available: Displays.available,
                key: Displays.key,
                outputs: Displays.outputs.map(o => o.name),
                countdown: Displays.countdown,
                enabled: Object.keys(Displays.current).filter(k => Displays.current[k].enabled),
                error: Displays.error
            } : undefined,
            parts: root.live.filter(name => root.services[name] === undefined),
            center: center !== null ? {
                open: center.shown,
                view: center.view,
                focus: center.focusKey,
                screen: center.screenInfo ? center.screenInfo.name : ""
            } : undefined,
            clock: clock !== null ? {
                open: clock.shown
            } : undefined,
            settingsPanel: settings !== null ? {
                open: settings.wanted,
                section: settings.section,
                group: settings.group
            } : undefined,
            sky: root.on("Sky") ? Sky.state() : undefined,
            weather: root.on("Weather") ? Weather.state() : undefined,
            diver: root.on("Diver") ? Diver.state() : undefined,
            notifications: root.on("Notifications") ? Notifications.state() : undefined,
            pad: pad !== null ? {
                open: pad.wanted,
                query: pad.query,
                results: pad.results.length,
                page: pad.page,
                pages: pad.pageList.length,
                selected: pad.selected,
                launched: Apps.lastLaunched
            } : undefined,
            switcher: root.part("switcher") !== null ? root.part("switcher").state() : undefined,
            lock: root.part("lock") !== null ? root.part("lock").state() : undefined,
            polkit: root.part("polkit") !== null ? root.part("polkit").state() : undefined,
            clip: root.part("clip") !== null ? root.part("clip").state() : undefined,
            island: root.part("island") !== null ? root.part("island").state() : undefined,
            capture: root.part("capture") !== null ? root.part("capture").state() : undefined,
            viewer: root.part("viewer") !== null ? root.part("viewer").state() : undefined,
            files: root.part("files") !== null ? root.part("files").state() : undefined,
            archive: root.part("archive") !== null ? root.part("archive").state() : undefined,
            access: root.part("access") !== null ? root.part("access").state() : undefined,
            fatest: root.part("fatest") !== null ? root.part("fatest").state() : undefined,
            rgb: root.part("rgb") !== null ? root.part("rgb").state() : undefined,
            keybinds: Keybinds.applied,
            sync: root.on("Sync") ? Sync.state() : undefined,
            plugins: root.on("Plugins") ? Plugins.state() : undefined,
            config: Config.values,
            configNotice: Config.notice,
            settings: Settings.values,
            settingsNotice: Settings.notice,
            glass: {
                values: Resin.values,
                notice: Resin.notice
            },
            theme: {
                id: Theme.currentId,
                active: Theme.theme.id,
                name: Theme.theme.name,
                errors: Theme.errors,
                ids: Theme.ids,
                tokens: Theme.target,
                catalog: Object.keys(Theme.catalog).sort(),
                hookError: Theme.hookError,
                linked: Theme.linked,
                open: theme !== null && theme.shown,
                front: theme !== null ? theme.front : null,
                original: theme !== null ? ThemePreview.original : null,
                applied: theme !== null ? ThemePreview.applied : null
            }
        };
        for (const key of Object.keys(out)) {
            if (out[key] === undefined)
                delete out[key];
        }
        return out;
    }

    LazyLoader {
        id: centerLoader
        active: root.on("center")

        SylCenter {
            id: centerPart
            peers: root.parts
            onPartRequested: name => {
                const p = root.part(name);
                if (p !== null)
                    p.open();
            }
            onShownChanged: {
                if (centerPart.shown)
                    root.solo(centerPart);
            }
        }
    }

    LazyLoader {
        id: themeLoader
        active: root.on("theme")

        SylTheme {
            id: themePart
            onOpened: root.solo(themePart)
        }
    }

    LazyLoader {
        id: clockLoader
        active: root.on("clock")

        SylClock {
            id: clockPart
            onOpened: root.solo(clockPart)
        }
    }

    LazyLoader {
        id: notifyLoader
        active: root.on("notify")

        SylNotify {
            id: notifyPart
            onOpened: root.solo(notifyPart)
        }
    }

    LazyLoader {
        id: padLoader
        active: root.on("pad")

        SylPad {
            id: padPart
            tiles: root.on("settings") ? M.tiles().filter(t => (t.id !== "sylvaris.diver" || Diver.plugged) && (t.id !== "sylvaris.fatest" || root.on("fatest")) && (t.id !== "sylvaris.rgb" || root.on("rgb"))) : []
            onOpened: root.solo(padPart)
            onSettingsRequested: section => root.need("settings").showSection(section)
        }
    }

    LazyLoader {
        id: mediaLoader
        active: root.on("media")

        SylMedia {
            id: mediaPart
            onOpened: root.solo(mediaPart)
        }
    }

    LazyLoader {
        id: settingsLoader
        active: root.on("settings")

        SylSettings {
            id: settingsPart
            onOpened: root.solo(settingsPart)
            onPartRequested: (name, arg) => {
                const p = root.part(name);
                if (p === null)
                    return;
                if (name === "center") {
                    p.setView(arg);
                    return;
                }
                if (name === "media")
                    p.openTab(arg);
                p.open();
            }
        }
    }

    LazyLoader {
        id: powerLoader
        active: root.on("power")

        SylPower {
            id: powerPart
            onOpened: root.solo(powerPart)
        }
    }

    LazyLoader {
        id: paperLoader
        active: root.on("paper")

        SylPaper {
            id: paperPart
            onOpened: root.solo(paperPart)
        }
    }

    LazyLoader {
        id: diverLoader
        active: root.on("diver")

        SylDiver {
            id: diverPart
            onOpened: root.solo(diverPart)
        }
    }

    LazyLoader {
        id: fatestLoader
        active: root.on("fatest")

        FaTest {
            id: fatestPart
            onOpened: root.solo(fatestPart)
        }
    }

    LazyLoader {
        id: rgbLoader
        active: root.on("rgb")

        SylRGB {
            id: rgbPart
            onOpened: root.solo(rgbPart)
        }
    }

    LazyLoader {
        id: syncLoader
        active: root.on("sync")

        SylSync {}
    }

    LazyLoader {
        id: pluginsLoader
        active: root.on("plugins")

        SylPlugins {
            id: pluginsPart
            onOpened: root.solo(pluginsPart)
        }
    }

    LazyLoader {
        id: accessLoader
        active: root.on("access")

        SylAccess {
            id: accessPart
            onOpened: root.solo(accessPart)
        }
    }

    LazyLoader {
        id: captureLoader
        active: root.on("capture")

        SylCapture {
            id: capturePart
            onOpened: root.solo(capturePart)
        }
    }

    LazyLoader {
        id: viewerLoader
        active: root.on("viewer")

        SylViewer {
            id: viewerPart
            onOpened: root.solo(viewerPart)
        }
    }

    LazyLoader {
        id: filesLoader
        active: root.on("files")

        SylFiles {
            id: filesPart
            onOpened: root.solo(filesPart)
        }
    }

    LazyLoader {
        id: archiveLoader
        active: root.on("archive")

        SylArchive {
            id: archivePart
            onOpened: root.solo(archivePart)
        }
    }

    LazyLoader {
        id: islandLoader
        active: root.on("island")

        SylIsland {
            id: islandPart
            peers: root.parts
            live: root.live
            avoid: root.openPanel
            onInsetChanged: {
                for (const name of Object.keys(root.parts)) {
                    const p = root.part(name);
                    if (p !== null && p.fromInset !== undefined && p.from !== "")
                        p.fromInset = islandPart.inset;
                }
            }
            onRequested: part => {
                const p = root.part(part);
                if (p !== null && p.toggleFrom !== undefined)
                    p.toggleFrom(islandPart.screenInfo, islandPart.cfg.position, islandPart.inset);
                else
                    root.openOn(part, "", islandPart.screenInfo);
            }
        }
    }

    LazyLoader {
        id: clipLoader
        active: root.on("clip")

        SylClip {
            id: clipPart
            onOpened: root.solo(clipPart)
        }
    }

    LazyLoader {
        id: polkitLoader
        active: root.on("polkit")

        SylPolkit {
            id: polkitPart
            onOpened: root.solo(polkitPart)
        }
    }

    LazyLoader {
        id: lockLoader
        active: root.on("lock")

        SylLock {
            id: lockPart
            onOpened: root.solo(lockPart)
        }
    }

    LazyLoader {
        id: switcherLoader
        active: root.on("switcher")

        SylSwitch {
            id: switcherPart
            onOpened: root.solo(switcherPart)
        }
    }

    LazyLoader {
        active: root.on("notify")

        Toasts {
            avoid: root.openPanel
        }
    }

    LazyLoader {
        active: root.on("bar")

        Scope {
            Variants {
                model: Quickshell.screens

                SylBar {
                    required property var modelData
                    screens: [modelData]
                    open: ({
                            center: root.screenOf(root.part("center")),
                            clock: root.screenOf(root.part("clock")),
                            notify: root.screenOf(root.part("notify")),
                            pad: root.screenOf(root.part("pad")),
                            power: root.screenOf(root.part("power"))
                        })
                    onRequest: (name, arg, screen) => root.openOn(name, arg, screen)
                }
            }
        }
    }

    LazyLoader {
        active: root.on("deck")

        Scope {
            Variants {
                model: Quickshell.screens

                SylDeck {
                    required property var modelData
                    screens: [modelData]
                    padOpen: root.part("pad") !== null && root.part("pad").wanted
                    onRequest: (name, arg, screen) => root.openOn(name, arg, screen)
                }
            }
        }
    }

    function setting(key: string, value: string): string {
        if (key === "")
            throw new Error("usage: set <key> <value>");
        if (Settings.frozen)
            throw new Error(Settings.notice);
        if (!Settings.trySet(key, I.parseValue(value)))
            throw new Error(Settings.get(key) === undefined ? "unknown setting: " + key : "invalid value for " + key + ", it stays " + JSON.stringify(Settings.get(key)));
        return JSON.stringify(Settings.get(key));
    }

    readonly property var owners: ({
            center: "center",
            clock: "clock",
            pad: "pad",
            paper: "paper",
            power: "power",
            notify: "Notifications",
            diver: "Diver",
            weather: "Weather",
            audio: "Audio",
            media: "Media",
            eq: "Equalizer",
            headphones: "Headphones",
            nightlight: "NightLight",
            dnd: "Dnd",
            wifi: "NetworkService",
            bluetooth: "BluetoothService"
        })

    readonly property var commands: {
        const all = ({
            center: {
                toggle: () => root.need("center").toggle(),
                open: () => root.need("center").open(),
                close: () => root.need("center").close(),
                view: name => {
                    if (name === undefined)
                        throw new Error("usage: center view <name>");
                    if (name === "theme")
                        root.need("theme").open();
                    else
                        root.need("center").setView(name);
                }
            },
            theme: {
                toggle: () => root.need("theme").toggle(),
                open: () => root.need("theme").open(),
                close: () => root.need("theme").close(),
                next: () => root.need("theme").step(1),
                prev: () => root.need("theme").step(-1),
                apply: () => root.need("theme").commit(),
                cycle: () => Theme.cycle(),
                search: (...q) => {
                    root.need("theme").query = q.join(" ");
                    return root.need("theme").ids;
                },
                set: id => {
                    if (Theme.ids.indexOf(id) < 0)
                        throw new Error("unknown theme: " + id);
                    Theme.apply(id);
                },
                list: () => Theme.ids
            },
            clock: {
                toggle: () => root.need("clock").toggle(),
                open: () => root.need("clock").open(),
                close: () => root.need("clock").close(),
                day: key => {
                    const c = root.need("clock");
                    const d = key === undefined || key === "today" ? Qt.formatDate(new Date(), "yyyy-MM-dd") : key;
                    if (!/^\d{4}-\d{2}-\d{2}$/.test(d))
                        throw new Error("usage: clock day <yyyy-mm-dd|today>");
                    c.open();
                    c.picked = d;
                }
            },
            notify: {
                toggle: () => root.need("notify").toggle(),
                open: () => root.need("notify").open(),
                close: () => root.need("notify").close(),
                clear: () => Notifications.clear(),
                dismiss: id => {
                    if (Notifications.entry(Number(id)) === null)
                        throw new Error("no notification with id " + id);
                    Notifications.dismiss(Number(id));
                },
                invoke: (id, action) => {
                    if (Notifications.entry(Number(id)) === null)
                        throw new Error("no notification with id " + id);
                    Notifications.invoke(Number(id), action || "default");
                }
            },
            settings: {
                toggle: () => root.need("settings").toggle(),
                open: section => root.need("settings").showSection(section || ""),
                close: () => root.need("settings").close(),
                screen: name => {
                    const n = String(name || "");
                    if (n !== "all" && n !== "" && Quickshell.screens.every(s => s.name !== n))
                        throw new Error("usage: settings screen <all|" + Quickshell.screens.map(s => s.name).join("|") + ">");
                    Settings.editing = n === "all" ? "" : n;
                },
                all: () => Settings.values,
                get: key => Settings.get(key) === undefined ? null : Settings.get(key),
                set: (key, ...rest) => root.setting(key || "", rest.join(" "))
            },
            diver: I.gated({
                default: "state",
                state: () => Diver.state(),
                sync: () => Diver.sync(),
                toggle: () => root.need("diver").toggle(),
                open: () => root.need("diver").open(),
                close: () => root.need("diver").close(),
                view: v => {
                    const d = root.need("diver");
                    d.panel.setView(v || "");
                    d.open();
                },
                new: (...words) => {
                    root.need("diver");
                    Diver.request("new", words.join(" "), "");
                },
                edit: id => {
                    root.need("diver");
                    if (Diver.find(id || "") === null)
                        throw new Error("no task with id " + id);
                    Diver.request("edit", id, "");
                },
                day: key => {
                    root.need("diver");
                    const d = key === undefined || key === "today" ? Qt.formatDate(new Date(), "yyyy-MM-dd") : key;
                    if (!/^\d{4}-\d{2}-\d{2}$/.test(d))
                        throw new Error("usage: diver day <yyyy-mm-dd|today>");
                    Diver.request("day", "", d);
                },
                delete: id => Diver.remove(id || ""),
                set: (id, field, ...value) => Diver.setField(id || "", field || "", value.join(" ")),
                move: (id, where) => Diver.move(id || "", where || ""),
                list: (verb, path, ...name) => Diver.listOp(verb || "", path === undefined ? "" : path, name.join(" ")),
                lists: () => Diver.lists(),
                focus: (id, minutes) => Diver.startFocus(id || "", Number(minutes || 0)),
                unfocus: () => Diver.stopFocus(),
                pause: () => Diver.pauseFocus(),
                resume: () => Diver.resumeFocus(),
                more: minutes => Diver.extendFocus(Number(minutes || 5)),
                late: () => Diver.moveOverdue(),
                pair: code => Diver.pair(code || ""),
                unpair: () => Diver.unpair(),
                add: (...words) => {
                    if (words.length === 0)
                        throw new Error("usage: diver add <text, e.g. call mom tomorrow 18:00>");
                    return Diver.add(words.join(" "), "");
                },
                done: id => Diver.done(id || ""),
                snooze: (id, minutes) => Diver.snooze(id || "", Number(minutes || 10)),
                today: () => Diver.state().today,
                next: () => Diver.state().next,
                test: () => {
                    Diver.alarm = {
                        rid: "test",
                        id: "",
                        at: Date.now(),
                        start: Date.now(),
                        before: 0,
                        alarm: true,
                        title: "This is how a Diver alarm looks",
                        path: "test"
                    };
                },
                dismiss: () => Diver.dismiss()
            }, () => Diver.plugged, Diver.offText),
            weather: {
                default: "state",
                state: () => Weather.state(),
                refresh: () => Weather.refresh()
            },
            paper: {
                toggle: () => root.need("paper").toggle(),
                open: () => root.need("paper").open(),
                close: () => root.need("paper").close(),
                set: (...p) => root.need("paper").set(p.join(" ")),
                next: () => root.need("paper").step(1),
                prev: () => root.need("paper").step(-1),
                reset: () => root.need("paper").reset(),
                current: () => root.need("paper").current
            },
            power: {
                toggle: () => root.need("power").toggle(),
                open: () => root.need("power").open(),
                close: () => root.need("power").close(),
                list: () => root.need("power").ids,
                run: id => root.need("power").run(id || "")
            },
            pad: {
                toggle: () => root.need("pad").toggle(),
                open: () => root.need("pad").open(),
                close: () => root.need("pad").close(),
                pick: (input, output, ...prompt) => root.need("pad").pick(input || "", output || "", prompt.join(" "))
            },
            sync: {
                default: "state",
                now: () => Sync.apply(),
                on: () => Settings.set("sync.enabled", true),
                off: () => Settings.set("sync.enabled", false),
                state: () => Sync.state()
            },
            plugins: {
                default: "list",
                toggle: () => root.need("plugins").toggle(),
                open: id => id ? root.need("plugins").openPlugin(id) : root.need("plugins").open(),
                close: () => root.need("plugins").close(),
                list: () => Plugins.state().plugins,
                enable: id => {
                    if (Plugins.byId(id || "") === null)
                        throw new Error("no working plugin called " + id);
                    Plugins.setEnabled(id, true);
                },
                disable: id => Plugins.setEnabled(id || "", false),
                new: (id, kind) => Plugins.create(id || "", kind || "bar"),
                install: url => Plugins.install(url || ""),
                pending: () => Plugins.pendingText(),
                confirm: () => Plugins.confirm(),
                discard: () => Plugins.discard(),
                remove: id => Plugins.remove(id || ""),
                refresh: () => Plugins.refresh(),
                state: () => Plugins.state()
            },
            access: {
                toggle: () => root.need("access").toggle(),
                open: () => root.need("access").open(),
                close: () => root.need("access").close(),
                zoom: v => root.need("access").zoom(v || "in"),
                filter: name => root.need("access").filter(name || "none"),
                state: () => root.need("access").state()
            },
            fatest: I.gated({
                default: "state",
                toggle: () => root.need("fatest").toggle(),
                open: () => root.need("fatest").open(),
                close: () => root.need("fatest").close(),
                run: () => {
                    const p = root.need("fatest");
                    p.run();
                    p.open();
                },
                stop: () => root.need("fatest").stop(),
                history: () => root.need("fatest").history,
                state: () => root.need("fatest").state()
            }, () => root.part("fatest") !== null, "FaTest is off; turn it on in SylSettings › Plugins or with: sylvaris plugins enable fatest"),
            rgb: I.gated({
                default: "state",
                toggle: () => root.need("rgb").toggle(),
                open: () => root.need("rgb").open(),
                close: () => root.need("rgb").close(),
                on: () => root.need("rgb").setOn(true),
                off: () => root.need("rgb").setOn(false),
                color: (value, ...device) => root.need("rgb").setColor(String(value || ""), device),
                mode: (name, ...device) => root.need("rgb").setMode(String(name || ""), device),
                follow: v => root.need("rgb").setFollow(v !== "off" && v !== "false"),
                brightness: v => root.need("rgb").setBrightness(Number(v)),
                press: (value, ...device) => root.need("rgb").setPress(String(value || ""), device),
                vivid: v => Settings.set("rgb.vivid", v !== "off" && v !== "false"),
                profile: (...name) => root.need("rgb").loadProfile(name.join(" ")),
                refresh: () => root.need("rgb").refresh(),
                restart: () => root.need("rgb").restart(),
                list: () => root.need("rgb").state().devices.map(d => d.name + " (" + d.type + "): " + d.modes.join(", ")).join("\n"),
                state: () => root.need("rgb").state()
            }, () => root.part("rgb") !== null, "SylRGB is off; turn it on in SylSettings › Plugins or with: sylvaris plugins enable rgb"),
            capture: {
                toggle: () => root.need("capture").toggle(),
                open: () => root.need("capture").open(),
                close: () => root.need("capture").close(),
                shot: mode => root.need("capture").shoot(mode || "region"),
                record: mode => root.need("capture").record(mode || "region"),
                stop: () => root.need("capture").stop(),
                edit: (...file) => root.need("capture").edit(file.join(" ")),
                state: () => root.need("capture").state()
            },
            island: {
                default: "state",
                toggle: () => root.need("island").toggle(),
                open: () => root.need("island").open(),
                close: () => root.need("island").close(),
                show: (...words) => root.need("island").say(words.join(" ")),
                run: id => root.need("island").runShortcut(String(id || "")),
                answer: () => root.need("island").act("call", "accept"),
                mute: () => root.need("island").act("voice", "mute"),
                decline: () => root.need("island").act("call", "decline"),
                reply: (...words) => root.need("island").act("message", words.length === 0 ? "reply" : "send:" + words.join(" ")),
                state: () => root.need("island").state()
            },
            files: {
                default: "state",
                open: (...p) => root.need("files").open(p.join(" ")),
                toggle: () => root.need("files").toggle(),
                close: () => root.need("files").close(),
                go: (...p) => root.need("files").goTo(p.join(" ")),
                tab: (...p) => root.need("files").openTab(p.join(" ")),
                select: (...names) => root.need("files").selectNames(names),
                search: (...q) => root.need("files").search(q.join(" ")),
                rename: (...n) => root.need("files").renameTo(n.join(" ")),
                act: action => root.need("files").act(String(action || "")),
                drives: () => root.need("files").drives,
                mount: (...n) => root.need("files").driveVerb("open", n.join(" ")),
                eject: (...n) => root.need("files").driveVerb("eject", n.join(" ")),
                state: () => root.need("files").state()
            },
            archive: {
                default: "state",
                open: (...p) => root.need("archive").open(p.join(" ")),
                close: () => root.need("archive").close(),
                go: (...p) => root.need("archive").goTo(p.join(" ")),
                select: (...names) => root.need("archive").selectNames(names),
                search: (...q) => root.need("archive").search(q.join(" ")),
                extract: (...dest) => {
                    const a = root.need("archive");
                    if (!a.wanted)
                        throw new Error("SylArchive is not open; open an archive with: sylvaris archive open <file>");
                    if (dest.length === 0)
                        a.act(a.selected.length > 0 ? "extract" : "extractAll");
                    else
                        a.extractText(dest.join(" "));
                },
                add: (...p) => root.need("archive").addFiles(p),
                act: action => root.need("archive").act(String(action || "")),
                state: () => root.need("archive").state()
            },
            viewer: {
                default: "state",
                open: (...p) => root.need("viewer").open(p.join(" ")),
                toggle: () => root.need("viewer").toggle(),
                close: () => root.need("viewer").close(),
                next: () => root.need("viewer").step(1),
                prev: () => root.need("viewer").step(-1),
                play: () => root.need("viewer").play(),
                copy: () => root.need("viewer").copy(),
                wallpaper: () => root.need("viewer").wallpaper(),
                trash: () => root.need("viewer").trash(),
                state: () => root.need("viewer").state()
            },
            clip: {
                toggle: () => root.need("clip").toggle(),
                open: () => root.need("clip").open(),
                close: () => root.need("clip").close(),
                clear: () => root.need("clip").clear(),
                list: () => root.need("clip").state().items,
                copy: n => {
                    const c = root.need("clip");
                    const e = c.shownList[Number(n || 1) - 1];
                    if (e === undefined)
                        throw new Error("usage: clip copy <number from clip list>");
                    c.copy(e);
                },
                state: () => root.need("clip").state()
            },
            polkit: {
                default: "state",
                state: () => root.need("polkit").state(),
                preview: () => root.need("polkit").showPreview(),
                cancel: () => root.need("polkit").cancel()
            },
            lock: {
                default: "now",
                now: () => root.need("lock").lock(),
                state: () => root.need("lock").state()
            },
            switcher: {
                default: "next",
                next: () => root.need("switcher").step(1),
                prev: () => root.need("switcher").step(-1),
                commit: () => root.need("switcher").commit(),
                close: () => root.need("switcher").close(),
                state: () => root.need("switcher").state()
            },
            wm: {
                default: "state",
                state: () => Compositor.state(),
                workspace: (...a) => Compositor.run("workspace", a),
                "move-to": (...a) => Compositor.run("move-to", a),
                focus: (...a) => Compositor.run("focus", a),
                move: (...a) => Compositor.run("move", a),
                close: () => Compositor.run("close", []),
                minimize: () => Compositor.minimize(Compositor.activeWindow),
                restore: () => Compositor.restore(Compositor.windows.find(w => w.minimized) || Compositor.windows[0] || null),
                fullscreen: () => Compositor.run("fullscreen", []),
                float: () => Compositor.run("float", []),
                exec: (...a) => Compositor.run("exec", a),
                reload: () => Compositor.run("reload", []),
                quit: () => Compositor.run("quit", [])
            },
            audio: {
                default: "mute",
                up: step => Audio.setVolume(Audio.volume + Number(step || 5) / 100),
                down: step => Audio.setVolume(Audio.volume - Number(step || 5) / 100),
                set: v => Audio.setVolume(Number(v) / 100),
                mute: () => Audio.toggleMute()
            },
            media: {
                toggle: () => Media.toggle(),
                next: () => Media.next(),
                previous: () => Media.previous(),
                seek: s => Media.seekTo(Number(s)),
                open: tab => {
                    if (tab !== undefined)
                        root.need("media").openTab(tab);
                    root.need("media").open();
                },
                close: () => root.need("media").close(),
                panel: () => root.need("media").toggle()
            },
            eq: {
                toggle: () => Equalizer.set({
                        enabled: !Equalizer.cfg.enabled
                    }),
                on: () => Equalizer.set({
                        enabled: true
                    }),
                off: () => Equalizer.set({
                        enabled: false
                    }),
                preset: name => {
                    if (E.PRESETS[name] === undefined)
                        throw new Error("presets: " + Object.keys(E.PRESETS).join(", "));
                    Equalizer.set({
                        preset: name,
                        enabled: true
                    });
                },
                band: (i, db) => {
                    const n = Number(i);
                    if (!(n >= 1 && n <= E.BANDS.length) || isNaN(Number(db)))
                        throw new Error("usage: eq band <1-" + E.BANDS.length + "> <dB>");
                    Equalizer.setBand(n - 1, Math.max(-E.LIMIT, Math.min(E.LIMIT, Number(db))));
                },
                spatial: v => Equalizer.set({
                        spatial: v === undefined ? !Equalizer.cfg.spatial : v === "on"
                    })
            },
            headphones: {
                default: "state",
                state: () => Headphones.state(),
                noise: mode => Headphones.setNoise(mode),
                awareness: v => Headphones.setAwareness(v === undefined ? !Headphones.awareness : v === "on")
            },
            privacy: {
                default: "toggle",
                toggle: () => Privacy.set(!Privacy.active),
                on: () => Privacy.set(true),
                off: () => Privacy.set(false),
                state: () => Privacy.state()
            },
            nightlight: {
                toggle: () => NightLight.setEnabled(!NightLight.enabled),
                on: () => NightLight.setEnabled(true),
                off: () => NightLight.setEnabled(false)
            },
            dnd: {
                toggle: () => Dnd.setEnabled(!Dnd.enabled),
                on: () => Dnd.setEnabled(true),
                off: () => Dnd.setEnabled(false)
            },
            wifi: {
                toggle: () => NetworkService.setEnabled(!NetworkService.enabled),
                on: () => NetworkService.setEnabled(true),
                off: () => NetworkService.setEnabled(false),
                connect: (...name) => {
                    if (NetworkService.item(name.join(" ")) === null)
                        throw new Error("usage: wifi connect <network name from sylvaris state>");
                    NetworkService.connect(name.join(" "));
                },
                disconnect: (...name) => NetworkService.disconnect(name.join(" "))
            },
            bluetooth: {
                toggle: () => BluetoothService.setEnabled(!BluetoothService.enabled),
                on: () => BluetoothService.setEnabled(true),
                off: () => BluetoothService.setEnabled(false),
                connect: address => {
                    if (!BluetoothService.items.some(i => i.key === address))
                        throw new Error("usage: bluetooth connect <device address from sylvaris state>");
                    BluetoothService.connect(address);
                },
                disconnect: address => BluetoothService.disconnect(address || "")
            },
            state: {
                default: "all",
                all: () => root.stateObject(),
                get: key => {
                    const v = root.stateObject()[key];
                    if (v === undefined)
                        throw new Error("unknown state topic: " + key);
                    return v;
                }
            },
            list: {
                default: "all",
                all: () => Ipc.list()
            },
            shell: {
                default: "config",
                reload: () => Quickshell.reload(false),
                config: () => ({
                        folder: Config.dir,
                        config: Config.path,
                        settings: Settings.path,
                        themes: Theme.themesDir,
                        state: Theme.stateFile
                    })
            }
        });
        const out = {};
        for (const name of Object.keys(all)) {
            if (root.owners[name] === undefined || root.on(root.owners[name]) || name === "diver" && Settings.values.parts.diver !== false)
                out[name] = all[name];
        }
        return out;
    }

    Binding {
        target: Tokens
        property: "lite"
        value: Settings.values.performance || Config.values.toggles.some(t => t.id === "performance") && Settings.values.toggleState.performance === true
    }

    Binding {
        target: Tokens
        property: "iconTint"
        value: Settings.values.iconTint
    }

    Binding {
        target: Tokens
        property: "textScale"
        value: Settings.values.access.text
    }

    Binding {
        target: Tokens
        property: "motion"
        value: Settings.values.motion.reduced ? 0.01 : Settings.values.motion.scale
    }

    Binding {
        target: Ipc
        property: "commands"
        value: root.commands
    }

    Binding {
        target: Ipc
        property: "snapshot"
        value: root.stateObject()
    }

    IpcHandler {
        target: "sylvaris"

        function run(request: string): string {
            const r = I.parseRequest(request);
            return r.ok ? Ipc.run(r.words) : "error: " + r.error;
        }
    }
}
