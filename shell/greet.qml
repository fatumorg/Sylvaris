import QtQuick
import SylStack
import qs.greet
import qs

ShellRoot {
    LookBindings {}

    SylGreet {
        id: greet
    }

    SocketServer {
        active: true
        path: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/greet.sock"
        handler: Socket {
            id: client

            parser: SplitParser {
                onRead: line => {
                    client.write(JSON.stringify(greet.state()) + "\n");
                    client.flush();
                    client.connected = false;
                }
            }
        }
    }
}
