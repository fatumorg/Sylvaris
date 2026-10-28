import QtQuick
import SylStack
import qs.lock
import qs

ShellRoot {
    LookBindings {}

    LockSession {
        id: session
    }

    SocketServer {
        active: true
        path: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/lock.sock"
        handler: Socket {
            id: client

            parser: SplitParser {
                onRead: line => {
                    if (line === "lock")
                        session.relock();
                    client.write(JSON.stringify(session.state()) + "\n");
                    client.flush();
                    client.connected = false;
                }
            }
        }
    }
}
