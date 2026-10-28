import QtQuick
import SylStack
import qs
import qs.services
import "../../lib/widgets.mjs" as Wd

Item {
    id: root

    property var frame: null
    readonly property var item: root.frame !== null ? root.frame.item : null
    readonly property string socket: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/kitty-" + (root.item !== null ? root.item.id : "x") + ".sock"
    readonly property var rect: root.frame !== null ? root.frame.rect : null
    property bool ok: false
    property string error: ""
    property var exits: []
    property string launched: ""

    function args(): var {
        return Wd.kittyArgs(root.item, root.rect, root.frame.screenName, root.socket);
    }

    function launch(): void {
        if (!root.ok || root.item === null || root.rect === null)
            return;
        kitty.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && rm -f \"$1\" && shift && exec kitty \"$@\"", "sh", root.socket].concat(root.args());
        root.launched = JSON.stringify(root.rect);
        kitty.running = true;
    }

    onRectChanged: {
        if (root.rect === null || !kitty.running || JSON.stringify(root.rect) === root.launched)
            return;
        root.launched = JSON.stringify(root.rect);
        mover.command = ["kitty"].concat(Wd.moveArgs(root.rect, root.socket));
        mover.running = true;
    }

    Component.onCompleted: version.running = true
    Component.onDestruction: kitty.running = false

    Process {
        id: version
        command: ["kitty", "--version"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ok = Wd.kittyOk(text);
                root.error = root.ok ? "" : "The terminal widget needs kitty 0.42 or newer";
                root.launch();
            }
        }
        onExited: code => {
            if (code !== 0)
                root.error = "Install kitty to use the terminal widget";
        }
    }

    Process {
        id: kitty
        onExited: () => {
            const now = Date.now();
            root.exits = root.exits.concat([now]).slice(-5);
            if (root.item !== null && root.item.options.restart && Wd.shouldRestart(root.exits, now))
                relaunch.restart();
            else if (root.item !== null && root.item.options.restart)
                root.error = "The command keeps ending; check it in SylSettings › Desktop › Widgets";
        }
    }

    Process {
        id: mover
    }

    Timer {
        id: relaunch
        interval: 800
        onTriggered: root.launch()
    }

    Text {
        textFormat: Text.PlainText
        visible: root.error !== ""
        anchors.centerIn: parent
        width: parent.width - 24
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        text: root.error
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }
}
