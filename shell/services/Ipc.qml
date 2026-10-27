pragma Singleton

import QtQuick
import SylStack
import "../lib/ipc.mjs" as I

Singleton {
    id: root

    property var commands: ({})
    property var snapshot: ({})
    property var last: ({})
    property var watchers: []
    readonly property string dir: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris"
    readonly property string socketPath: root.dir + "/ipc.sock"
    property bool ready: false

    function run(words: var): string {
        return I.format(I.dispatch(root.commands, words));
    }

    function list(): var {
        return I.describe(root.commands);
    }

    function watch(socket: var, topics: var): void {
        root.watchers = root.watchers.filter(w => w.socket !== socket).concat([
            {
                socket: socket,
                topics: topics
            }
        ]);
        for (const topic of Object.keys(root.last)) {
            if (topics.length === 0 || topics.indexOf(topic) >= 0)
                root.send(socket, topic, root.last[topic]);
        }
    }

    function drop(socket: var): void {
        root.watchers = root.watchers.filter(w => w.socket !== socket);
    }

    function send(socket: var, topic: string, json: string): void {
        socket.write("{\"topic\":" + JSON.stringify(topic) + ",\"data\":" + json + "}\n");
        socket.flush();
    }

    function emit(topic: string, data: var): void {
        const json = JSON.stringify(data === undefined ? null : data);
        for (const w of root.watchers) {
            if (w.topics.length === 0 || w.topics.indexOf(topic) >= 0)
                root.send(w.socket, topic, json);
        }
    }

    onSnapshotChanged: {
        const next = I.topics(root.snapshot);
        for (const topic of I.changed(root.last, next))
            root.emit(topic, root.snapshot[topic]);
        root.last = next;
    }

    Process {
        running: true
        command: ["sh", "-c", "mkdir -p -m 700 \"$1\" && chmod 700 \"$1\" && rm -f \"$2\"", "sylvaris-ipc", root.dir, root.socketPath]
        onExited: code => {
            root.ready = code === 0;
            if (code !== 0)
                console.warn("sylvaris: could not prepare " + root.dir + " for the ipc socket");
        }
    }

    SocketServer {
        active: root.ready
        path: root.socketPath
        handler: Socket {
            id: client

            onConnectedChanged: {
                if (!connected)
                    root.drop(client);
            }

            parser: SplitParser {
                onRead: line => {
                    const r = I.parseRequest(line);
                    if (!r.ok) {
                        client.write(JSON.stringify({
                            ok: false,
                            error: r.error
                        }) + "\n");
                        client.flush();
                    } else if (line.indexOf(I.SEP) >= 0) {
                        client.write(root.run(r.words) + "\n");
                        client.flush();
                        client.connected = false;
                    } else if (r.words[0] === "watch") {
                        root.watch(client, r.words.slice(1));
                    } else {
                        client.write(JSON.stringify(I.dispatch(root.commands, r.words)) + "\n");
                        client.flush();
                    }
                }
            }
        }
    }
}
