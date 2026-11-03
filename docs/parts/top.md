# SylTop

A task manager in the Sylvaris look. It is on by default and opens as a normal window:

```sh
sylvaris top                 # open or close it
sylvaris top open performance
sylvaris top find firefox    # open Processes with a search
sylvaris top tag 1234 5678   # tag processes; again untags, no PIDs clears
sylvaris top state
```

It reads `/proc` through a small Python helper only while the window is open; closed, it runs no process and no timer. Turn it off completely with `sylvaris set parts.top false`, which also takes **Task manager** off the key bindings list.

## Pages

- **Processes**: every process with its PID, user, processor use, memory, threads, nice value and state. Click a column to sort by it, click again to flip the order. **Tree** nests each process under the one that started it, and the arrow folds a branch away; a search shows a flat list. Pick a process to end it (SIGTERM), kill it (SIGKILL), pause and resume it, lower or raise its priority, let it use the disk only when nothing else does, pin it to some processors, or list the files it has open. Right-click or Ctrl+click processes to tag them, and those buttons act on every tagged process at once; **Clear tags** goes back to one. Raising a priority, or touching another user's process, needs root and says so.
- **Performance**: history graphs of the last 60 samples for the processor, each thread, memory and swap, disk reads and writes, network traffic and every graphics card (AMD through sysfs, NVIDIA through `nvidia-smi` when it is installed). With [SylTemp](../plugins/temp.md) on, the main temperatures get graphs too.
- **Startup**: the apps in `~/.config/autostart` and the system autostart folders that run on this desktop, and your `systemd --user` services. Turning an app off writes your own copy of its file with `Hidden=true`, so the system file stays as it is.
- **Services**: system and user services with their state. Start, stop and restart; system ones go through `pkexec`, so [SylPolkit](polkit.md) asks for your password.
- **Users**: the login sessions from `loginctl`, with a button that shows that user's processes.

## Keys

Bind **Task manager** under SylSettings › System › Key bindings; Ctrl+Shift+Escape is a good fit and can be recorded there. The action is `sylvaris top toggle`.

## Settings

| Key (`top.`) | Default | Meaning |
|---|---|---|
| `interval` | `2` | seconds between samples, 1 to 5 |
| `tree` | `false` | show processes as a tree |
