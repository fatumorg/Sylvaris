import QtQuick
import SylStack
import qs.services
import "../lib/greet.mjs" as G

Scope {
    id: root

    readonly property string stateDir: Stack.env("SYLVARIS_GREET_STATE") || ""
    readonly property string wallpaper: Stack.env("SYLVARIS_GREET_WALLPAPER") || Theme.wallpaper
    readonly property string defaultUser: Stack.env("SYLVARIS_GREET_USER") || ""
    readonly property string defaultSession: Stack.env("SYLVARIS_GREET_SESSION") || ""
    readonly property string sessionDirs: Stack.env("SYLVARIS_GREET_SESSIONS") || "/run/current-system/sw/share/wayland-sessions:/usr/local/share/wayland-sessions:/usr/share/wayland-sessions"
    readonly property bool dry: Stack.env("SYLVARIS_GREET_DRY") === "1"
    readonly property string shared: Stack.env("SYLVARIS_GREET_SHARED") || ""
    readonly property string candidate: root.shared === "" || root.user === null ? "" : root.shared + "/" + root.user.id
    property string folder: ""
    property var users: []
    property var sessions: []
    property int userIndex: -1
    property int sessionIndex: -1
    property var last: ({})
    property bool busy: false
    property bool error: false
    property bool awaiting: false
    property bool echo: false
    property string message: ""
    property string pending: ""
    property string typed: ""
    readonly property string avatar: root.folder !== "" ? root.folder + "/avatar" : Config.values.avatar.indexOf("/") === 0 ? Config.values.avatar : root.user === null ? "" : root.user.home + "/.face"
    readonly property var mainScreen: Stack.screens.reduce((best, s) => best === null || s.width * s.height > best.width * best.height ? s : best, null)
    property string launched: ""
    property real now: Date.now()
    readonly property var user: root.userIndex >= 0 ? root.users[root.userIndex] : null
    readonly property var session: root.sessionIndex >= 0 ? root.sessions[root.sessionIndex] : null

    signal failed

    function choose(): void {
        root.userIndex = G.pick(root.users, root.last.user || "", root.defaultUser);
        root.sessionIndex = G.pick(root.sessions, root.last.session || "", root.defaultSession);
    }

    function stepUser(d: int): void {
        if (root.users.length < 2 || root.busy)
            return;
        root.cancel();
        root.error = false;
        root.message = "";
        root.userIndex = (root.userIndex + d + root.users.length) % root.users.length;
    }

    function stepSession(d: int): void {
        if (root.sessions.length < 2)
            return;
        root.sessionIndex = (root.sessionIndex + d + root.sessions.length) % root.sessions.length;
    }

    function pickSession(i: int): void {
        if (i >= 0 && i < root.sessions.length)
            root.sessionIndex = i;
    }

    function cancel(): void {
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        root.busy = false;
        root.awaiting = false;
        root.pending = "";
    }

    function submit(text: string): void {
        if (root.user === null || root.busy)
            return;
        if (!Greetd.available) {
            root.error = true;
            root.message = "greetd is not running";
            return;
        }
        root.typed = "";
        root.error = false;
        root.message = "";
        root.busy = true;
        if (root.awaiting) {
            root.awaiting = false;
            Greetd.respond(text);
            return;
        }
        root.pending = text;
        Greetd.createSession(root.user.id);
    }

    function power(action: string): void {
        if (root.dry) {
            root.launched = action;
            return;
        }
        Stack.execDetached(["sh", "-c", "systemctl \"$1\" 2>/dev/null || loginctl \"$1\"", "sh", action]);
    }

    onFolderChanged: Theme.folder = root.folder
    onCandidateChanged: {
        root.folder = "";
        ownerProc.running = false;
        if (root.candidate === "")
            return;
        ownerProc.command = ["stat", "-c", "%u", "--", root.candidate];
        ownerProc.running = true;
    }

    function state(): var {
        return {
            available: Greetd.available,
            users: root.users.map(u => u.id),
            user: root.user === null ? "" : root.user.id,
            sessions: root.sessions.map(s => s.id),
            session: root.session === null ? "" : root.session.id,
            busy: root.busy,
            error: root.error,
            message: root.message,
            launched: root.launched,
            theme: Theme.currentId
        };
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (root.pending !== "") {
                    const text = root.pending;
                    root.pending = "";
                    Greetd.respond(text);
                } else {
                    root.busy = false;
                    root.awaiting = true;
                    root.echo = echoResponse;
                    root.message = message;
                }
            } else {
                root.error = error;
                root.message = message;
                Greetd.respond("");
            }
        }
        function onAuthFailure(message) {
            root.busy = false;
            root.awaiting = false;
            root.pending = "";
            root.error = true;
            root.message = "Wrong password";
            root.failed();
        }
        function onError(err) {
            root.busy = false;
            root.awaiting = false;
            root.pending = "";
            root.error = true;
            root.message = err;
            root.failed();
        }
        function onReadyToLaunch() {
            if (root.stateDir !== "")
                lastFile.setText(JSON.stringify({
                    user: root.user.id,
                    session: root.session === null ? "" : root.session.id
                }));
            const cmd = root.session === null ? ["sh", "-l"] : G.splitExec(root.session.exec);
            root.launched = cmd.join(" ");
            Greetd.launch(cmd, [], true);
        }
    }

    Process {
        id: ownerProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.user !== null && text.trim() === String(root.user.uid) && ownerProc.command[4] === root.candidate)
                    root.folder = root.candidate;
            }
        }
    }

    FileView {
        path: Stack.env("SYLVARIS_GREET_PASSWD") || "/etc/passwd"
        printErrors: false
        onLoaded: {
            root.users = G.parsePasswd(text()).map(u => Object.assign({
                    id: u.name
                }, u));
            root.choose();
        }
    }

    FileView {
        id: lastFile
        path: root.stateDir === "" ? "" : root.stateDir + "/last.json"
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                root.last = JSON.parse(text());
            } catch (e) {
                root.last = {};
            }
            root.choose();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "IFS=:; for d in $0; do for f in \"$d\"/*.desktop; do [ -e \"$f\" ] && printf '@@%s\\n' \"$f\" && cat \"$f\"; done; done", root.sessionDirs]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessions = G.parseSessions(text);
                root.choose();
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Variants {
        model: Stack.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Theme.base
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylgreet"
            WlrLayershell.keyboardFocus: modelData === root.mainScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

            GreetView {
                anchors.fill: parent
                greet: root
            }
        }
    }
}
