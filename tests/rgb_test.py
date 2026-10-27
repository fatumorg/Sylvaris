import os
import socket
import struct
import sys
import tempfile
import threading
import unittest

here = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(here, "..", "shell", "helpers"))
sys.path.insert(0, here)
import fake_openrgb
import rgb


class RGBTest(unittest.TestCase):
    def serve(self, proto=5):
        srv = fake_openrgb.Server(0, proto=proto)
        self.addCleanup(srv.sock.close)
        return srv

    def ops(self, srv, kind, count=0):
        for _ in range(100):
            got = [e for e in srv.events if e["op"] == kind]
            if len(got) >= count:
                return got
            threading.Event().wait(0.02)
        return got

    def test_lists_devices_on_every_protocol(self):
        for proto in (0, 1, 3, 4, 5):
            srv = self.serve(proto)
            got = rgb.listing("127.0.0.1", srv.port)
            self.assertTrue(got["ok"], got)
            self.assertEqual(got["protocol"], proto)
            names = [d["name"] for d in got["devices"]]
            self.assertEqual(names, ["SteelSeries Rival 3 Wireless", "Krux Atax Pro RGB", "Gigabyte RGB"])
            mouse, keyboard, board = got["devices"]
            self.assertEqual(mouse["type"], "mouse")
            self.assertEqual(keyboard["type"], "keyboard")
            self.assertEqual(board["type"], "motherboard")
            self.assertEqual(mouse["mode"], "Static")
            self.assertEqual(mouse["color"], "#ff0000")
            self.assertEqual(keyboard["leds"], 3)
            self.assertEqual([m["name"] for m in keyboard["modes"]], ["Direct", "Static", "Spectrum Cycle", "Off"])
            self.assertEqual(keyboard["modes"][2]["color"], False)
            self.assertEqual(board["color"], "#00ff00")
            self.assertEqual(got["profiles"], ["Evening", "Work"] if proto >= 2 else [])
        self.assertEqual(self.ops(srv, "name", 1), [{"op": "name", "name": "Sylvaris"}])

    def test_colour_uses_leds_or_the_mode_colour(self):
        srv = self.serve()
        got = rgb.apply("127.0.0.1", srv.port, [
            {"id": 0, "name": "SteelSeries Rival 3 Wireless", "do": "color", "color": "#112233"},
            {"id": 2, "name": "Gigabyte RGB", "do": "color", "color": "#445566"},
        ])
        self.assertTrue(got["ok"], got)
        self.assertEqual([r["ok"] for r in got["results"]], [True, True])
        modes = self.ops(srv, "mode", 2)
        self.assertEqual(modes[0], {"op": "mode", "dev": "SteelSeries Rival 3 Wireless", "mode": "Static", "colors": ["#112233"], "speed": 0})
        self.assertEqual(modes[1], {"op": "mode", "dev": "Gigabyte RGB", "mode": "Static", "colors": ["#445566"], "speed": 0})
        self.assertEqual(self.ops(srv, "leds"), [])

    def test_colour_prefers_static_over_an_effect_and_turns_the_brightness_up(self):
        srv = self.serve()
        board = srv.devices[2]
        board["modes"].insert(0, fake_openrgb.mode("Color Wave", fake_openrgb.MODE_SPECIFIC, [(0, 0, 0)], flags=1 << 6))
        board["active"] = 0
        board["modes"][1]["brightness"] = 0
        got = rgb.apply("127.0.0.1", srv.port, [{"id": 2, "name": "Gigabyte RGB", "do": "color", "color": "#445566"}])
        self.assertTrue(got["results"][0]["ok"], got)
        self.assertEqual(self.ops(srv, "mode", 1)[-1]["mode"], "Static")
        self.assertEqual(board["modes"][1]["brightness"], 100)

    def test_fast_colour_keeps_to_direct_leds(self):
        srv = self.serve()
        got = rgb.apply("127.0.0.1", srv.port, [{"id": 0, "name": "SteelSeries Rival 3 Wireless", "do": "color", "color": "#112233", "fast": True}])
        self.assertTrue(got["results"][0]["ok"], got)
        self.assertEqual(self.ops(srv, "leds", 1), [{"op": "leds", "dev": "SteelSeries Rival 3 Wireless", "colors": ["#112233"]}])

    def test_effects_and_off(self):
        srv = self.serve()
        got = rgb.apply("127.0.0.1", srv.port, [
            {"id": 0, "name": "SteelSeries Rival 3 Wireless", "do": "mode", "mode": "breathing", "color": "#00ff88"},
            {"id": 1, "name": "Krux Atax Pro RGB", "do": "off"},
            {"id": 2, "name": "Gigabyte RGB", "do": "off"},
            {"id": 1, "name": "Krux Atax Pro RGB", "do": "mode", "mode": "Rainbow"},
        ])
        modes = self.ops(srv, "mode", 3)
        self.assertEqual(modes[0], {"op": "mode", "dev": "SteelSeries Rival 3 Wireless", "mode": "Breathing", "colors": ["#00ff88"], "speed": 3})
        self.assertEqual(modes[1]["mode"], "Off")
        self.assertEqual(modes[2], {"op": "mode", "dev": "Gigabyte RGB", "mode": "Static", "colors": ["#000000"], "speed": 0})
        self.assertEqual([r["ok"] for r in got["results"]], [True, True, True, False])
        self.assertIn("Rainbow", got["results"][3]["error"])

    def test_a_shifted_device_list_is_never_written_to(self):
        srv = self.serve()
        got = rgb.apply("127.0.0.1", srv.port, [{"id": 0, "name": "Krux Atax Pro RGB", "do": "color", "color": "#ffffff"}])
        self.assertTrue(got["ok"])
        self.assertTrue(got["results"][0]["ok"])
        self.assertEqual(self.ops(srv, "mode", 1), [{"op": "mode", "dev": "Krux Atax Pro RGB", "mode": "Static", "colors": ["#ffffff"], "speed": 0}])
        got = rgb.apply("127.0.0.1", srv.port, [{"id": 0, "name": "Gone Mouse", "do": "color", "color": "#ffffff"}])
        self.assertFalse(got["results"][0]["ok"])
        self.assertEqual(len(self.ops(srv, "mode")), 1)

    def test_bad_colours_are_refused(self):
        srv = self.serve()
        got = rgb.apply("127.0.0.1", srv.port, [{"id": 0, "name": "SteelSeries Rival 3 Wireless", "do": "color", "color": "red; rm -rf"}])
        self.assertFalse(got["results"][0]["ok"])
        self.assertEqual(self.ops(srv, "leds"), [])

    def test_profiles_load(self):
        srv = self.serve()
        got = rgb.load("127.0.0.1", srv.port, "Evening")
        self.assertTrue(got["ok"], got)
        self.assertEqual(self.ops(srv, "profile", 1), [{"op": "profile", "name": "Evening"}])
        self.assertEqual(len(self.ops(srv, "mode", 3)), 3)
        self.assertFalse(rgb.load("127.0.0.1", srv.port, "Nope")["ok"])

    def test_unreachable_server_explains_itself(self):
        probe = socket.socket()
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
        probe.close()
        got = rgb.listing("127.0.0.1", port)
        self.assertFalse(got["ok"])
        self.assertIn("OpenRGB", got["error"])

    def test_watch_reports_device_changes(self):
        srv = self.serve()
        seen = []
        done = threading.Event()

        def out(line):
            seen.append(line)
            if line == "changed":
                done.set()

        threading.Thread(target=rgb.watch, args=("127.0.0.1", srv.port, out), daemon=True).start()
        for _ in range(50):
            if srv.clients:
                break
            threading.Event().wait(0.05)
        threading.Event().wait(0.2)
        srv.notify()
        self.assertTrue(done.wait(3))
        self.assertEqual(seen[0], "ready")

    def test_watch_asks_for_a_rescan_once_plugged_devices_settle(self):
        srv = self.serve()
        plugged = [{"hidraw0"}]
        threading.Thread(target=rgb.watch, args=("127.0.0.1", srv.port, lambda line: None, lambda: plugged[0], 0.05), daemon=True).start()
        for _ in range(50):
            if srv.clients:
                break
            threading.Event().wait(0.05)
        threading.Event().wait(0.3)
        self.assertEqual(self.ops(srv, "rescan"), [])
        plugged[0] = {"hidraw0", "hidraw1"}
        self.assertEqual(len(self.ops(srv, "rescan", 1)), 1)
        threading.Event().wait(0.3)
        self.assertEqual(len(self.ops(srv, "rescan")), 1)

    def test_watch_survives_the_rescan_dropping_it_and_still_sees_a_replug(self):
        srv = self.serve()
        seen = []
        plugged = [{"hidraw0"}]
        t = threading.Thread(target=rgb.watch, args=("127.0.0.1", srv.port, seen.append, lambda: plugged[0], 0.05), daemon=True)
        t.start()
        threading.Event().wait(0.3)
        plugged[0] = set()
        self.assertEqual(len(self.ops(srv, "rescan", 1)), 1)
        threading.Event().wait(0.3)
        plugged[0] = {"hidraw0"}
        self.assertEqual(len(self.ops(srv, "rescan", 2)), 2)
        self.assertTrue(t.is_alive())
        self.assertIn("changed", seen)

    def test_list_carries_the_device_location(self):
        srv = self.serve()
        self.assertEqual(rgb.listing("127.0.0.1", srv.port)["devices"][0]["location"], "HID: fake")

    def test_event_nodes_follow_hidraw_to_the_usb_device(self):
        with tempfile.TemporaryDirectory() as root:
            usb = os.path.join(root, "devices", "usb7", "7-1")
            hid = os.path.join(usb, "7-1:1.1", "0003:1038:1838.0002")
            os.makedirs(os.path.join(hid, "hidraw", "hidraw5"))
            for iface, ev in (("7-1:1.0", "event8"), ("7-1:1.2", "event10")):
                os.makedirs(os.path.join(usb, iface, "0003:1038:1838.000" + ev[-1], "input", "input2" + ev[-1], ev))
            open(os.path.join(usb, "idVendor"), "w").write("1038\n")
            os.symlink(usb, os.path.join(usb, "7-1:1.0", "loop"))
            os.makedirs(os.path.join(root, "class", "hidraw", "hidraw5"))
            os.symlink(hid, os.path.join(root, "class", "hidraw", "hidraw5", "device"))
            self.assertEqual(rgb.event_nodes("HID: /dev/hidraw5", root), ["/dev/input/event10", "/dev/input/event8"])
            self.assertEqual(rgb.event_nodes("I2C: /dev/i2c-3", root), [])

    def test_quiet_click_turns_off_the_aerox_3_own_click_colour(self):
        with tempfile.TemporaryDirectory() as root:
            dev = os.path.join(root, "dev")
            os.makedirs(dev)
            for n, pid in ((5, "183a"), (6, "1838"), (7, "1702")):
                usb = os.path.join(root, "devices", "usb3", "3-%d" % n)
                hid = os.path.join(usb, "3-%d:1.3" % n, "0003:1038:%s.0001" % pid.upper())
                os.makedirs(os.path.join(hid, "hidraw", "hidraw%d" % n))
                open(os.path.join(usb, "idVendor"), "w").write("1038\n")
                open(os.path.join(usb, "idProduct"), "w").write(pid + "\n")
                os.makedirs(os.path.join(root, "class", "hidraw", "hidraw%d" % n))
                os.symlink(hid, os.path.join(root, "class", "hidraw", "hidraw%d" % n, "device"))
                open(os.path.join(dev, "hidraw%d" % n), "wb").close()
            for n in (5, 6, 7):
                rgb.quiet_click("HID: /dev/hidraw%d" % n, root, dev)
            read = lambda n: open(os.path.join(dev, "hidraw%d" % n), "rb").read()
            self.assertEqual(read(5), bytes([0x00, 0x26, 0, 0, 0, 0, 0]))
            self.assertEqual(read(6), bytes([0x00, 0x66, 0, 0, 0, 0, 0]))
            self.assertEqual(read(7), b"")
            rgb.quiet_click("HID: /dev/hidraw9", root, dev)

    def test_a_button_press_flashes_the_press_colour(self):
        srv = self.serve()
        with tempfile.TemporaryDirectory() as tmp:
            fifo = os.path.join(tmp, "event0")
            os.mkfifo(fifo)
            stop = threading.Event()
            target = {"id": 0, "name": "SteelSeries Rival 3 Wireless", "base": "#112233", "press": "#ffffff", "events": [fifo]}
            t = threading.Thread(target=rgb.react, args=("127.0.0.1", srv.port, [target], lambda line: None, stop.is_set), daemon=True)
            t.start()
            w = os.open(fifo, os.O_WRONLY)
            self.addCleanup(os.close, w)
            self.assertEqual(self.ops(srv, "leds", 1)[-1]["colors"], ["#112233"])

            def ev(kind, code, value):
                os.write(w, struct.pack("<qqHHi", 0, 0, kind, code, value))

            ev(4, 4, 589825)
            ev(1, 0x110, 1)
            ev(0, 0, 0)
            self.assertEqual(self.ops(srv, "leds", 2)[-1]["colors"], ["#ffffff"])
            ev(1, 0x111, 1)
            ev(1, 0x110, 0)
            ev(1, 30, 1)
            ev(1, 30, 0)
            threading.Event().wait(0.2)
            self.assertEqual(len(self.ops(srv, "leds")), 2)
            ev(1, 0x111, 0)
            self.assertEqual(self.ops(srv, "leds", 3)[-1]["colors"], ["#112233"])
            stop.set()
            t.join(3)
            self.assertFalse(t.is_alive())


if __name__ == "__main__":
    unittest.main()
