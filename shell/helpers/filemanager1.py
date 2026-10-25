import subprocess
import sys

METHODS = ("ShowFolders", "ShowItems", "ShowItemProperties")

XML = """<node>
  <interface name="org.freedesktop.FileManager1">
    <method name="ShowFolders"><arg type="as" name="URIs" direction="in"/><arg type="s" name="StartupId" direction="in"/></method>
    <method name="ShowItems"><arg type="as" name="URIs" direction="in"/><arg type="s" name="StartupId" direction="in"/></method>
    <method name="ShowItemProperties"><arg type="as" name="URIs" direction="in"/><arg type="s" name="StartupId" direction="in"/></method>
  </interface>
</node>"""


def commands(sylvaris, method, uris):
    if method not in METHODS:
        return []
    return [[sylvaris, "files", "open", u] for u in uris if u]


def main(argv):
    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib

    sylvaris = argv[1]
    loop = GLib.MainLoop()
    info = Gio.DBusNodeInfo.new_for_xml(XML)

    def call(conn, sender, path, iface, method, params, invocation):
        invocation.return_value(None)
        for cmd in commands(sylvaris, method, params.unpack()[0]):
            subprocess.Popen(cmd, start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def on_bus(conn, name):
        conn.register_object("/org/freedesktop/FileManager1", info.interfaces[0], call, None, None)

    Gio.bus_own_name(Gio.BusType.SESSION, "org.freedesktop.FileManager1", Gio.BusNameOwnerFlags.NONE, on_bus, None, lambda *_: loop.quit())
    loop.run()


if __name__ == "__main__":
    main(sys.argv)
