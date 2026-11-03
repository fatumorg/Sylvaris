(() => {
    if (typeof Services === "undefined" || Services.appinfo.processType !== Services.appinfo.PROCESS_TYPE_DEFAULT)
        return;
    Cu.importGlobalProperties(["IOUtils", "PathUtils"]);
    const { setInterval } = ChromeUtils.importESModule("resource://gre/modules/Timer.sys.mjs");
    const seen = {};
    let css = null;
    let gradient = null;
    let timer = null;
    const windows = () => Array.from(Services.wm.getEnumerator("navigator:browser"));
    const rgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));

    const paint = win => {
        const utils = win.windowUtils;
        if (win.sylvarisSheet)
            utils.removeSheetUsingURIString(win.sylvarisSheet, utils.USER_SHEET);
        win.sylvarisSheet = css === null ? "" : "data:text/css;charset=utf-8," + encodeURIComponent(css);
        if (win.sylvarisSheet)
            utils.loadSheetUsingURIString(win.sylvarisSheet, utils.USER_SHEET);
    };

    const tint = async win => {
        const spaces = win.gZenWorkspaces;
        const picker = win.gZenThemePicker;
        if (!spaces || !picker || gradient === null)
            return;
        await spaces.promiseInitialized;
        await picker.promiseInitialized;
        const colours = gradient.map((hex, i) => ({
            c: rgb(hex),
            isCustom: false,
            algorithm: "",
            isPrimary: i === 0,
            lightness: 50,
            position: picker.calculateInitialPosition(rgb(hex)),
            type: "explicit-lightness"
        }));
        const key = JSON.stringify(colours.map(c => c.c));
        const stale = spaces.getWorkspaces().filter(s => !s.theme || JSON.stringify((s.theme.gradientColors || []).map(c => c.c)) !== key);
        if (stale.length === 0)
            return;
        for (const space of stale) {
            const old = space.theme || {};
            spaces.saveWorkspace(Object.assign({}, space, {
                theme: { type: "gradient", gradientColors: colours, opacity: typeof old.opacity === "number" ? old.opacity : 0.5, texture: old.texture || 0 }
            }));
        }
        for (const w of windows())
            if (w.gZenThemePicker)
                for (const space of stale)
                    w.gZenThemePicker.invalidateGradientCache(space.uuid);
        picker.onWorkspaceChange(spaces.getActiveWorkspace());
        Services.obs.notifyObservers(null, "zen-space-gradient-update");
    };

    const changed = async name => {
        const path = PathUtils.join(PathUtils.profileDir, "chrome", name);
        let info = null;
        try {
            info = await IOUtils.stat(path);
        } catch (e) {
            if (seen[name] === undefined)
                return undefined;
            delete seen[name];
            return null;
        }
        if (seen[name] === info.lastModified)
            return undefined;
        seen[name] = info.lastModified;
        return IOUtils.readUTF8(path);
    };

    const check = async () => {
        const nextCss = await changed("sylvaris.css");
        if (nextCss !== undefined) {
            css = nextCss;
            windows().forEach(paint);
        }
        const nextJson = await changed("sylvaris.json");
        if (nextJson === undefined)
            return;
        try {
            const list = nextJson === null ? null : JSON.parse(nextJson).gradient;
            gradient = Array.isArray(list) && list.length > 0 && list.length <= 3 && list.every(h => /^#[0-9a-f]{6}$/i.test(h)) ? list : null;
        } catch (e) {
            gradient = null;
        }
        if (windows().length > 0)
            await tint(windows()[0]);
    };

    const tick = () => check().catch(e => Services.console.logStringMessage("sylvaris: " + e));

    Services.obs.addObserver(win => {
        if (css !== null)
            paint(win);
        if (timer !== null)
            return;
        timer = setInterval(tick, 2000);
        tick();
    }, "browser-delayed-startup-finished");
})();
