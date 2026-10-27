# Commands

Everything Sylvaris does is one command away. The same commands work from a terminal, from compositor key bindings, from scripts and over a socket.

```sh
sylvaris                 # start the shell
sylvaris center          # a part with no action runs its default, usually toggle
sylvaris list            # every part and its actions, as JSON
```

A command that fails prints `error: ...` and exits with 1, so scripts can rely on the exit code.

## Shortcuts

| Command | What it does |
|---|---|
| `sylvaris get <key>` | print a setting |
| `sylvaris set <key> <value>` | change a setting; refused, with the reason, if the value is not valid |
| `sylvaris state [topic]` | the whole state, or one topic such as `audio`, as JSON |
| `sylvaris watch [topic...]` | stream state changes as JSON lines |
| `sylvaris view <name>` | open SylCenter on a view |
| `sylvaris pick [prompt]` | choose one line from stdin in SylPad, like dmenu |
| `sylvaris choose MULTIPLE DIRECTORY SAVE PATH OUT` | an open or save dialog in SylFiles, called by xdg-desktop-portal-termfilechooser; see [SylFiles](parts/files.md#open-and-save-dialogs) |
| `sylvaris config` | where the configuration lives |
| `sylvaris reload` | reload the shell |
| `sylvaris doctor` | versions, missing tools and config problems, for bug reports |
| `sylvaris version` | print the version without starting anything |
| `sylvaris greet` | start the SylGreet login screen (for greetd) |

To show the version in fastfetch, add `{ "type": "command", "key": "DE", "text": "sylvaris version" }` to the `modules` list in `~/.config/fastfetch/config.jsonc`.

## Every part and its actions

| Part | Actions |
|---|---|
| `access` | `toggle` `open` `close` `zoom <in\|out\|1..5>` `filter <name>` `state` |
| `audio` | `up [step]` `down [step]` `set <0..100>` `mute` |
| `bluetooth` | `toggle` `on` `off` `connect <address>` `disconnect [address]` |
| `capture` | `toggle` `open` `close` `shot <area\|window\|screen>` `record <area\|screen>` `stop` `edit [file]` `state` |
| `center` | `toggle` `open` `close` `view <name>` |
| `clip` | `toggle` `open` `close` `clear` `list` `copy <n>` `state` |
| `clock` | `toggle` `open` `close` `day <yyyy-mm-dd\|today>` |
| `diver` | see [Diver](plugins/diver.md#commands) |
| `dnd` | `toggle` `on` `off` |
| `eq` | `toggle` `on` `off` `preset <name>` `band <1..10> <dB>` `spatial <on\|off>` |
| `fatest` | `toggle` `open` `close` `run` `stop` `history` `state` |
| `headphones` | `state` `noise <off\|transparency\|adaptive\|anc>` `awareness <on\|off>` |
| `island` | `toggle` `open` `close` `show <text>` `run <shortcut>` `answer` `decline` `reply <text>` `state` |
| `lock` | `now` `state` |
| `media` | `toggle` `next` `previous` `seek <seconds>` `open [tab]` `close` `panel` |
| `nightlight` | `toggle` `on` `off` |
| `privacy` | `toggle` `on` `off` `state`: mutes every microphone and switches USB cameras off; cameras need `programs.sylvaris.cameraSwitch.enable` on NixOS |
| `notify` | `toggle` `open` `close` `clear` `dismiss <id>` `invoke <id> [action]` |
| `pad` | `toggle` `open` `close` `pick` |
| `paper` | `toggle` `open` `close` `set <path>` `next` `prev` `reset` `current` |
| `plugins` | `toggle` `open [id]` `close` `list` `enable <id>` `disable <id>` `new <id> [kind]` `install <url>` `pending` `confirm` `discard` `remove <id>` `refresh` `state` |
| `polkit` | `state` `preview` `cancel` |
| `power` | `toggle` `open` `close` `list` `run <action>` |
| `settings` | `toggle` `open [section]` `close` `screen <all\|output>` `all` `get <key>` `set <key> <value>` |
| `shell` | `reload` `config` |
| `switcher` | `next` `prev` `commit` `close` `state` |
| `sync` | `now` `on` `off` `state` |
| `theme` | `toggle` `open` `close` `next` `prev` `apply` `cycle` `search <text>` `set <id>` `list` |
| `weather` | `state` `refresh` |
| `wifi` | `toggle` `on` `off` `connect <name>` `disconnect [name]` |
| `wm` | see [compositors](compositors.md#one-set-of-window-commands) |

Parts you turned off answer with an error that says how to turn them back on.

## The socket

`sylvaris watch` and fast commands use `$XDG_RUNTIME_DIR/sylvaris/ipc.sock`. Tools can talk to it directly: send one request per line, either plain words (`center toggle`) or a JSON array (`["center","view","orbit-wifi:My Network"]`), and read one JSON reply per line (`{"ok":true,"result":...}`). Sending `["watch","audio"]` turns the connection into a stream: every requested topic once, then a line each time one changes, such as `{"topic":"audio","data":{...}}`.

`sylvaris` talks to the socket with `sylstack msg`, so no other tool is needed. From a script, `sylstack msg "$XDG_RUNTIME_DIR/sylvaris/ipc.sock" 'center toggle'` sends one request and prints the reply; `sylstack msg -f` keeps the connection open for `watch`.
