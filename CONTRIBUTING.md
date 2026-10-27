# Contributing

Thanks for helping. Read [ARCHITECTURE.md](ARCHITECTURE.md) first; it explains how the shell is put together. This page covers setup, tests and the few rules every change follows.

## Setup

With Nix, everything you need is in the dev shell:

```sh
git clone https://github.com/fatumorg/Sylvaris
cd Sylvaris
nix develop
```

Without Nix, build SylStack with `make` (its build dependencies are listed in [docs/install.md](docs/install.md#build-sylstack)) and put `build/sylstack/sylstack` on your `PATH`, then install `nodejs`, `qt6-declarative` (for `qmllint`), `sway`, `grim`, `jq`, `wtype`, `wlrctl`, `wayvnc`, `vncdotool`, `dbus`, `libnotify`, `wlr-randr` and `wlsunset` from your distribution.

Run your working copy with `SYLVARIS_DIR=$PWD/shell bin/sylvaris`. Stop your normal Sylvaris first, or test in the headless harness below instead. If `SYLVARIS_DIR` is already set in your environment (the Nix package sets a default), it points the CLI and the harness at the installed copy; unset it or set it to your checkout.

## Tests

Run the checks for what you touched while you work, and all of them before you open a pull request.

| What | Command |
|---|---|
| Logic in `shell/lib` | `node --test tests/<name>.test.mjs` (all: `node --test tests/*.test.mjs`) |
| SylStack | `nix build .#sylstack`, or `make` without Nix |
| Python helpers | `python3 -m unittest discover -s tests -p '*_test.py'` |
| QML | `qmllint` with the import paths from `flake.nix`; `nix flake check` runs it on every file |
| Runtime and visuals | `tests/headless/run.sh OUT tests/headless/<name>.steps tests/fixtures/seed/warm` |
| Every headless scenario | `tests/headless/all.sh` |
| Everything, as CI does | `nix flake check` |
| Memory and CPU | `tests/bench/bench.sh [OUT]` (see the README for what it measures) |

New logic in `shell/lib` comes with a failing node test first. New or changed behaviour you can see or trigger gets a headless scenario.

### Headless harness

`tests/headless/run.sh` starts a private sway with no real outputs or input devices, a private D-Bus and a fresh home, seeds `~/.config` from a fixture, starts the shell in demo mode (`SYLVARIS_DEMO=1`, fixture data instead of real devices) and runs a `.steps` file line by line. Nothing touches your screens, devices or session.

| Step | Does |
|---|---|
| `sleep <s>` | wait |
| `syl <words>` | run `bin/sylvaris <words>`, output goes to `OUT/ipc.log` |
| `ipc <words>` | send the words straight to the entry's socket with `sylstack msg` (`ipc.sock`, or `lock.sock` and `greet.sock` for those entries) |
| `bg <shell>` | run a shell command in the background, inside the session |
| `shot <name>` | screenshot to `OUT/<name>.png` |
| `write <path> <text>` | write a file under the test home's `.config` |
| `sway <args>` | run `swaymsg` |
| `check <shell>` | assert: the run fails if the command exits non-zero (`$OUT` is the output folder, `$SHELL_PID` the shell's process) |
| `killshell` | kill the main shell process with SIGKILL |
| `pointer <vncdo commands>` | real pointer input through wayvnc, e.g. `pointer move 400 300 click 1` or `pointer move 10 10 mousedown 1 drag 200 120 mouseup 1` |
| `mark <label>` | write a timestamp to `ipc.log` |

`wtype` drops the first key of each call, so steps type `wtype -k Shift_L <text>`. Useful variables: `SYLVARIS_DEMO=0` (real services), `SYLVARIS_PAM_DIR` (test PAM services in `tests/fixtures/pam`), `HL_ENTRY` (another entry file, e.g. `greet.qml`), `HL_RENDERER=gles2 HL_QT_BACKEND=rhi` (render with OpenGL, which album art and theme photos need; software rendering is the default).

## Rules

**No comments in code.** No `//`, `/* */`, `#`, `<!-- -->`, doc comments, TODOs or commented-out code in any tracked code file; `tests/comments.test.mjs` checks every one. Names, structure and tests carry the meaning; explanations belong in these documents, in `docs/`, or in the pull request. Shebangs, `pragma Singleton`, `.pragma library` and `#` inside strings are fine. If a linter warns, fix the cause or configure the linter in its config file.

**Everything through the shared pieces.** Surfaces use `Glass`; colours come from `Theme`, sizes from `Tokens`, motion from `lib/motion.mjs`. Reuse `Toggle`, `Segmented`, `Card`, `SettingRow`, `RowButton`, `Glyph` and the existing services before writing new ones. Every interactive element has hover, pressed, focus and disabled states.

**Three compositors.** A feature works on Hyprland, niri and sway, or it is gated by a flag in `CAPABILITIES` in `shell/lib/wm.mjs` and says clearly where it is unavailable. Only `services/Compositor.qml` and `lib/wm.mjs` may know which compositor is running.

**Settings.** Every new key gets a default and a validator in `lib/settings.mjs`, a control in SylSettings, a test, and a regenerated `nix/schema.json`. Never change the meaning of an existing key without a migration step.

**Disabled means off.** A part that is turned off runs no process, timer or watcher.

**Secrets stay secret.** Passwords, Diver keys and tokens never appear in state, logs, fixtures or commits.

## Adding a part

A new part is complete when it has its directory and `SylX.qml`, registration in `shell.qml` and `lib/modules.mjs`, IPC actions, defaults and validators, a SylSettings section with a live preview, a SylPad entry that opens its settings, a Home Manager option, its runtime tools in `nix/package.nix` and `lib/doctor.mjs`, unit tests for its `lib` logic, a headless scenario, and a clean enable and disable.

## Commits

One logical change per commit. Subject line only, lowercase, imperative, at most 72 characters, with a type prefix:

```
feat: add a clear button to key binding pills
fix: give slurp an empty stdin so area capture does not hang
docs: mark SylLock, SylGreet and SylPolkit as experimental
```

Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`, `chore`. Add one body line only when the reason is not obvious from the subject. Stage files by path, and keep unrelated changes out.

## Bugs

Use the bug report form and paste the output of `sylvaris doctor`.
