import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shell", "helpers"))
import top


def write(root, rel, text):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def proc(root, pid, comm, ppid, utime, stime, rss, cmd, state="S", nice=0, threads=1, start=100):
    rest = [state, ppid, 1, 1, 0, -1, 0, 0, 0, 0, 0, utime, stime, 0, 0, 20, nice, threads, 0, start, 1000, rss]
    write(root, f"proc/{pid}/stat", f"{pid} ({comm}) " + " ".join(str(x) for x in rest) + " 0 0\n")
    write(root, f"proc/{pid}/cmdline", "\0".join(cmd) + "\0")


def fake(root, ticks, utime, read, rx):
    write(root, "proc/stat", f"cpu  {ticks} 0 {ticks} {1000 + 2 * ticks} 0 0 0 0 0 0\ncpu0 {ticks} 0 0 {500 + ticks} 0 0 0 0 0 0\ncpu1 0 0 {ticks} {500 + ticks} 0 0 0 0 0 0\nintr 1\n")
    write(root, "proc/meminfo", "MemTotal:       1000 kB\nMemFree:         100 kB\nMemAvailable:    400 kB\nSwapTotal:       200 kB\nSwapFree:         50 kB\n")
    write(root, "proc/diskstats", f"   8       0 sda 1 0 {read} 0 1 0 {read * 2} 0 0 0 0\n   8       1 sda1 1 0 999999 0 1 0 999999 0 0 0 0\n   7       0 loop0 1 0 999999 0 1 0 0 0 0 0 0\n")
    write(root, "proc/net/dev", f"Inter-|   Receive\n face |bytes\n    lo: 999999 0 0 0 0 0 0 0 999999 0 0 0 0 0 0 0\n  eth0: {rx} 0 0 0 0 0 0 0 {rx // 2} 0 0 0 0 0 0 0\n")
    proc(root, 1, "init", 0, 10, 0, 100, ["/sbin/init"])
    proc(root, 42, "my (odd) app", 1, utime, 0, 2000, ["/usr/bin/app", "--flag"], state="R", nice=5, threads=3)


class TopTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def sample(self):
        fake(self.root, 100, 50, 1000, 10000)
        a = top.snapshot(self.root, 10.0)
        fake(self.root, 200, 150, 3000, 30000)
        b = top.snapshot(self.root, 12.0)
        return top.sample(a, b)

    def test_cpu_per_core_and_total(self):
        s = self.sample()
        self.assertEqual(s["cpu"]["total"], 50.0)
        self.assertEqual(s["cpu"]["cores"], [50.0, 50.0])

    def test_memory_and_swap_in_bytes(self):
        m = self.sample()["mem"]
        self.assertEqual(m, {"total": 1024000, "used": 614400, "available": 409600, "swapTotal": 204800, "swapUsed": 153600})

    def test_disk_and_network_rates_skip_partitions_loops_and_lo(self):
        s = self.sample()
        self.assertEqual(s["disk"], {"read": 512000.0, "write": 1024000.0})
        self.assertEqual(s["net"], {"rx": 10000.0, "tx": 5000.0})

    def test_every_amd_card_is_listed_with_its_memory(self):
        for card, busy, used in (("card0", 3, 100), ("card1", 40, 900)):
            write(self.root, f"sys/class/drm/{card}/device/gpu_busy_percent", f"{busy}\n")
            write(self.root, f"sys/class/drm/{card}/device/mem_info_vram_used", f"{used}\n")
            write(self.root, f"sys/class/drm/{card}/device/mem_info_vram_total", "1000\n")
        self.assertEqual(top.gpus(self.root), [{"name": "card0", "busy": 3, "memUsed": 100, "memTotal": 1000}, {"name": "card1", "busy": 40, "memUsed": 900, "memTotal": 1000}])
        self.assertEqual(self.sample()["gpus"][1]["busy"], 40)

    def test_long_command_lines_are_cut(self):
        fake(self.root, 100, 50, 1000, 10000)
        proc(self.root, 50, "long", 1, 0, 0, 1, ["x" * 1000])
        self.assertEqual(len(top.snapshot(self.root, 1.0)["procs"][50]["cmd"]), 240)

    def test_processes_with_odd_names_cpu_and_memory(self):
        procs = {p["pid"]: p for p in self.sample()["procs"]}
        app = procs[42]
        self.assertEqual(app["name"], "my (odd) app")
        self.assertEqual(app["ppid"], 1)
        self.assertEqual(app["cmd"], "/usr/bin/app --flag")
        self.assertEqual(app["state"], "R")
        self.assertEqual(app["nice"], 5)
        self.assertEqual(app["threads"], 3)
        self.assertEqual(app["mem"], 2000 * top.PAGE)
        self.assertEqual(app["cpu"], round(100 / top.HZ / 2 * 100, 1))
        self.assertEqual(procs[1]["cpu"], 0.0)

    def test_a_process_that_vanishes_mid_read_is_skipped(self):
        fake(self.root, 100, 50, 1000, 10000)
        os.makedirs(os.path.join(self.root, "proc", "77"))
        a = top.snapshot(self.root, 1.0)
        self.assertNotIn(77, a["procs"])

    def test_commands_are_checked_before_they_run(self):
        with self.assertRaises(ValueError):
            top.command({"cmd": "signal", "pid": 42, "sig": "hup"})
        with self.assertRaises(ValueError):
            top.command({"cmd": "signal", "pid": 0, "sig": "term"})
        with self.assertRaises(ValueError):
            top.command({"cmd": "renice", "pid": 42, "nice": 40})
        with self.assertRaises(ValueError):
            top.command({"cmd": "ionice", "pid": 42, "class": "turbo", "level": 0})
        with self.assertRaises(ValueError):
            top.command({"cmd": "affinity", "pid": 42, "cpus": []})
        with self.assertRaises(ValueError):
            top.command({"cmd": "nope"})

    def test_files_and_detail_read_proc(self):
        fd = os.path.join(self.root, "proc", "42", "fd")
        os.makedirs(fd)
        os.symlink("/home/me/notes.txt", os.path.join(fd, "3"))
        os.symlink("socket:[123]", os.path.join(fd, "4"))
        self.assertEqual(top.files(self.root, 42), [{"fd": 3, "target": "/home/me/notes.txt"}, {"fd": 4, "target": "socket:[123]"}])
        self.assertEqual(top.files(self.root, 99), [])

    def test_interval_and_signal_commands(self):
        self.assertEqual(top.command({"cmd": "interval", "seconds": 0.1}), {"interval": 0.5})
        self.assertEqual(top.command({"cmd": "interval", "seconds": 9}), {"interval": 5.0})
        sent = []
        real = os.kill
        os.kill = lambda pid, sig: sent.append((pid, sig))
        try:
            top.command({"cmd": "signal", "pid": 42, "sig": "stop"})
        finally:
            os.kill = real
        self.assertEqual(sent, [(42, top.SIGNALS["stop"])])

    def test_answer_turns_lines_into_events(self):
        fake(self.root, 100, 50, 1000, 10000)
        self.assertEqual(top.answer(self.root, '{"cmd":"files","pid":42}'), {"event": "files", "pid": 42, "files": []})
        self.assertEqual(top.answer(self.root, "not json")["event"], "error")
        self.assertEqual(top.answer(self.root, '{"cmd":"signal","pid":42,"sig":"boom"}')["event"], "error")
        self.assertEqual(top.answer(self.root, '{"cmd":"interval","seconds":2}'), {"event": "done", "cmd": "interval", "interval": 2.0})

    def test_autostart_merges_user_over_system_and_reads_hidden(self):
        user, system = os.path.join(self.root, "home", "autostart"), os.path.join(self.root, "xdg", "autostart")
        write(self.root, "xdg/autostart/agent.desktop", "[Desktop Entry]\nType=Application\nName=Agent\nExec=agent\n")
        write(self.root, "xdg/autostart/gnome.desktop", "[Desktop Entry]\nName=Gnome\nX-GNOME-Autostart-enabled=false\n")
        write(self.root, "home/autostart/chat.desktop", "[Desktop Entry]\nName=Chat\nExec=chat --tray\nHidden=true\n[Desktop Action x]\nName=Other\n")
        write(self.root, "home/autostart/notes.txt", "x")
        write(self.root, "xdg/autostart/kde.desktop", "[Desktop Entry]\nName=Kde\nOnlyShowIn=KDE;\n")
        write(self.root, "xdg/autostart/nohypr.desktop", "[Desktop Entry]\nName=No\nNotShowIn=Hyprland;\n")
        write(self.root, "xdg/autostart/chat.desktop", "[Desktop Entry]\nName=System chat\n")
        apps = top.autostart(user, [system], ["Hyprland"])
        self.assertEqual([(a["file"], a["name"], a["on"], a["mine"]) for a in apps], [("agent.desktop", "Agent", True, False), ("chat.desktop", "Chat", False, True), ("gnome.desktop", "Gnome", False, False)])

    def test_set_autostart_writes_a_user_copy_and_flips_hidden(self):
        user, system = os.path.join(self.root, "home", "autostart"), os.path.join(self.root, "xdg", "autostart")
        write(self.root, "xdg/autostart/agent.desktop", "[Desktop Entry]\nName=Agent\nExec=agent\nX-GNOME-Autostart-enabled=true\n[Desktop Action a]\nName=A\n")
        top.set_autostart(user, [system], "agent.desktop", False)
        self.assertEqual(top.entry(os.path.join(user, "agent.desktop"))["Hidden"], "true")
        self.assertNotIn("X-GNOME-Autostart-enabled", top.entry(os.path.join(user, "agent.desktop")))
        self.assertIn("[Desktop Action a]", top.read(os.path.join(user, "agent.desktop")))
        self.assertEqual(top.autostart(user, [system])[0]["on"], False)
        top.set_autostart(user, [system], "agent.desktop", True)
        self.assertEqual(top.autostart(user, [system])[0]["on"], True)
        self.assertNotIn("Hidden=true", top.read(os.path.join(system, "agent.desktop")))
        with self.assertRaises(ValueError):
            top.set_autostart(user, [system], "../evil.desktop", True)
        with self.assertRaises(ValueError):
            top.set_autostart(user, [system], "missing.desktop", True)

    def test_unit_actions_are_checked_and_system_ones_go_through_pkexec(self):
        self.assertEqual(top.unit_args({"scope": "user", "verb": "enable", "name": "syncthing.service"}), ["systemctl", "--user", "enable", "--", "syncthing.service"])
        self.assertEqual(top.unit_args({"scope": "system", "verb": "restart", "name": "bluetooth.service"}), ["pkexec", "systemctl", "restart", "--", "bluetooth.service"])
        for bad in ({"scope": "system", "verb": "enable", "name": "a.service"}, {"scope": "user", "verb": "mask", "name": "a.service"}, {"scope": "user", "verb": "stop", "name": "-x.service"}, {"scope": "user", "verb": "stop", "name": "a;b.service"}, {"scope": "root", "verb": "stop", "name": "a.service"}):
            with self.assertRaises(ValueError):
                top.unit_args(bad)


if __name__ == "__main__":
    unittest.main()
