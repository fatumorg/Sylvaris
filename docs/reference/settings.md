# Settings reference

Every key Sylvaris reads from `settings.json`, with its default. The same keys work in `config.json` and as Home Manager options under `programs.sylvaris`, and `sylvaris set <key> <value>` changes any of them. Keys marked per screen can also be set for one screen under `screens.<output>` (see [one screen at a time](../configuration.md#one-screen-at-a-time)).

This page is generated from the shell's defaults by `node site/reference.mjs`, so it always matches the code.

## center

Explained in [center](../parts/center.md).

| Key | Default | Per screen |
|---|---|:---:|
| `center.corner` | `"top-right"` | yes |
| `center.hidden` | `[]` |  |
| `center.extra` | `[]` |  |
| `center.volume` | `true` |  |
| `center.media` | `true` |  |

## clock

Explained in [clock](../parts/clock.md).

| Key | Default | Per screen |
|---|---|:---:|
| `clock.corner` | `"top-center"` | yes |

## nightLight

Explained in [center](../parts/center.md).

| Key | Default | Per screen |
|---|---|:---:|
| `nightLight.enabled` | `false` |  |
| `nightLight.temperature` | `4000` |  |

## displays

Explained in [center](../parts/center.md#displays).

| Key | Default | Per screen |
|---|---|:---:|
| `displays.layouts` | `{}` |  |

## toggleState

Explained in [configuration](../configuration.md#custom-toggles).

| Key | Default | Per screen |
|---|---|:---:|
| `toggleState` | `{}` |  |

## hotspot

Explained in [center](../parts/center.md#hotspot).

| Key | Default | Per screen |
|---|---|:---:|
| `hotspot.ssid` | `"Sylvaris"` |  |
| `hotspot.band` | `"bg"` |  |

## notifications

Explained in [notify](../parts/notify.md).

| Key | Default | Per screen |
|---|---|:---:|
| `notifications.dnd` | `false` |  |
| `notifications.timeout` | `5000` |  |
| `notifications.corner` | `"top-right"` | yes |

## pad

Explained in [pad](../parts/pad.md).

| Key | Default | Per screen |
|---|---|:---:|
| `pad.columns` | `7` |  |
| `pad.rows` | `5` |  |
| `pad.mode` | `"launchpad"` |  |

## bar

Explained in [bar](../parts/bar.md).

| Key | Default | Per screen |
|---|---|:---:|
| `bar.workspaceIcons` | `"auto"` | yes |
| `bar.enabled` | `true` | yes |
| `bar.floating` | `true` | yes |
| `bar.position` | `"top"` | yes |
| `bar.style` | `"islands"` | yes |
| `bar.left` | `["pad","workspaces","window"]` | yes |
| `bar.center` | `["clock"]` | yes |
| `bar.right` | `["media","tray","audio","network","bluetooth","battery","...` | yes |

## deck

Explained in [deck](../parts/deck.md).

| Key | Default | Per screen |
|---|---|:---:|
| `deck.enabled` | `false` | yes |
| `deck.pinned` | `[]` |  |
| `deck.pad` | `"start"` | yes |
| `deck.power` | `"none"` | yes |
| `deck.effect` | `"bloom"` | yes |
| `deck.hide` | `"never"` | yes |
| `deck.peek` | `true` | yes |
| `deck.peekSize` | `4` | yes |
| `deck.reserve` | `true` | yes |
| `deck.size` | `56` | yes |

## media

Explained in [media](../parts/media.md).

| Key | Default | Per screen |
|---|---|:---:|
| `media.eq.enabled` | `false` |  |
| `media.eq.preset` | `"flat"` |  |
| `media.eq.bands` | `[0,0,0,0,0,0,0,0,0,0]` |  |
| `media.eq.spatial` | `false` |  |
| `media.eq.spatialLevel` | `0.45` |  |
| `media.airpods` | `""` |  |

## motion

Explained in [look](../look.md#motion-and-performance).

| Key | Default | Per screen |
|---|---|:---:|
| `motion.scale` | `1` |  |
| `motion.reduced` | `false` |  |
| `motion.reveal` | `"edges"` |  |

## power

Explained in [power](../parts/power.md).

| Key | Default | Per screen |
|---|---|:---:|
| `power.actions` | `["lock","suspend","logout","reboot","shutdown"]` |  |
| `power.confirm` | `true` |  |
| `power.countdown` | `3` |  |
| `power.commands` | `{}` |  |

## paper

Explained in [paper](../parts/paper.md).

| Key | Default | Per screen |
|---|---|:---:|
| `paper.enabled` | `true` |  |
| `paper.folder` | `"~/Pictures/wallpapers"` |  |
| `paper.themes` | `{}` |  |
| `paper.outputs` | `{}` |  |
| `paper.fit` | `"cover"` | yes |
| `paper.blur` | `0` | yes |
| `paper.dim` | `0` | yes |
| `paper.tint` | `0` | yes |
| `paper.transition` | `"zoom"` | yes |
| `paper.duration` | `900` | yes |
| `paper.drift` | `false` | yes |

## weather

Explained in [clock](../parts/clock.md).

| Key | Default | Per screen |
|---|---|:---:|
| `weather.enabled` | `true` |  |
| `weather.units` | `"metric"` |  |
| `weather.refresh` | `30` |  |

## diver

Explained in [plugins/diver](../plugins/diver.md).

| Key | Default | Per screen |
|---|---|:---:|
| `diver.enabled` | `true` |  |
| `diver.refresh` | `2` |  |
| `diver.notify` | `true` |  |
| `diver.alarms` | `true` |  |
| `diver.sound` | `true` |  |
| `diver.calendar` | `true` |  |

## constellation

Explained in [settings](../parts/settings.md).

| Key | Default | Per screen |
|---|---|:---:|
| `constellation.speed` | `1` |  |
| `constellation.links` | `true` |  |
| `constellation.ring` | `true` |  |
| `constellation.labels` | `true` |  |
| `constellation.stars` | `true` |  |

## switcher

Explained in [switcher](../parts/switcher.md).

| Key | Default | Per screen |
|---|---|:---:|
| `switcher.previews` | `true` |  |
| `switcher.titles` | `true` |  |

## lock

Explained in [lock](../parts/lock.md).

| Key | Default | Per screen |
|---|---|:---:|
| `lock.pam` | `""` |  |
| `lock.logind` | `false` |  |
| `lock.seconds` | `false` |  |

## clip

Explained in [clip](../parts/clip.md).

| Key | Default | Per screen |
|---|---|:---:|
| `clip.limit` | `50` |  |
| `clip.persist` | `false` |  |
| `clip.images` | `true` |  |

## island

Explained in [island](../parts/island.md).

| Key | Default | Per screen |
|---|---|:---:|
| `island.media` | `true` |  |
| `island.recording` | `true` |  |
| `island.diver` | `true` |  |
| `island.volume` | `true` |  |
| `island.devices` | `true` |  |
| `island.notifications` | `false` |  |
| `island.messages` | `true` |  |
| `island.calls` | `true` |  |
| `island.pinCalls` | `true` |  |
| `island.privacy` | `true` |  |
| `island.status` | `true` |  |
| `island.keepPaused` | `true` |  |
| `island.hover` | `true` |  |
| `island.seconds` | `5` |  |
| `island.position` | `"top-center"` | yes |
| `island.idle` | `"pill"` | yes |
| `island.reveal` | `"always"` | yes |
| `island.shortcuts` | `["notify","center","media","screenshot","record","dnd"]` | yes |
| `island.screens` | `"focused"` |  |
| `island.hideSites` | `["youtube.com","youtu.be"]` |  |

## viewer

| Key | Default | Per screen |
|---|---|:---:|
| `viewer.autoplay` | `true` |  |
| `viewer.loop` | `true` |  |
| `viewer.muted` | `false` |  |

## files

| Key | Default | Per screen |
|---|---|:---:|
| `files.view` | `"grid"` |  |
| `files.iconSize` | `64` |  |
| `files.sort` | `"name"` |  |
| `files.descending` | `false` |  |
| `files.foldersFirst` | `true` |  |
| `files.hidden` | `false` |  |
| `files.thumbnails` | `true` |  |
| `files.icons` | `"glyphs"` |  |
| `files.sidebar` | `true` |  |
| `files.details` | `false` |  |
| `files.click` | `"double"` |  |
| `files.typing` | `"filter"` |  |
| `files.start` | `"~"` |  |
| `files.confirmTrash` | `false` |  |
| `files.bookmarks` | `[]` |  |
| `files.keys` | `{}` |  |

## archive

| Key | Default | Per screen |
|---|---|:---:|
| `archive.view` | `"list"` |  |
| `archive.format` | `"zip"` |  |
| `archive.level` | `"normal"` |  |
| `archive.extract` | `"smart"` |  |
| `archive.reveal` | `true` |  |
| `archive.keys` | `{}` |  |

## rgb

Explained in [plugins/rgb](../plugins/rgb.md).

| Key | Default | Per screen |
|---|---|:---:|
| `rgb.on` | `true` |  |
| `rgb.color` | `""` |  |
| `rgb.follow` | `false` |  |
| `rgb.vivid` | `true` |  |
| `rgb.brightness` | `100` |  |
| `rgb.restore` | `true` |  |
| `rgb.devices` | `{}` |  |
| `rgb.host` | `"127.0.0.1"` |  |
| `rgb.port` | `6742` |  |

## placement

Explained in [configuration](../configuration.md#where-panels-open).

| Key | Default | Per screen |
|---|---|:---:|
| `placement.media` | `"auto"` | yes |
| `placement.clip` | `"top-center"` | yes |
| `placement.capture` | `"top-center"` | yes |
| `placement.access` | `"top-center"` | yes |
| `placement.diver` | `"center"` | yes |
| `placement.fatest` | `"top-right"` | yes |
| `placement.rgb` | `"top-right"` | yes |

## screens

Explained in [configuration](../configuration.md#one-screen-at-a-time).

| Key | Default | Per screen |
|---|---|:---:|
| `screens` | `{}` |  |

## capture

Explained in [capture](../parts/capture.md).

| Key | Default | Per screen |
|---|---|:---:|
| `capture.folder` | `"~/Pictures/Screenshots"` |  |
| `capture.videos` | `"~/Videos/Recordings"` |  |
| `capture.copy` | `true` |  |
| `capture.save` | `true` |  |
| `capture.delay` | `0` |  |
| `capture.audio` | `false` |  |
| `capture.format` | `"png"` |  |
| `capture.quality` | `90` |  |
| `capture.cursor` | `false` |  |
| `capture.scale` | `0` |  |
| `capture.after` | `"notify"` |  |
| `capture.pattern` | `"{kind} {date} {time}"` |  |
| `capture.fps` | `0` |  |
| `capture.resolution` | `"native"` |  |
| `capture.codec` | `"h264"` |  |
| `capture.container` | `"mp4"` |  |
| `capture.videoQuality` | `"balanced"` |  |
| `capture.audioSource` | `"output"` |  |
| `capture.constant` | `false` |  |
| `capture.limit` | `0` |  |
| `capture.countdown` | `0` |  |

## access

Explained in [access](../parts/access.md).

| Key | Default | Per screen |
|---|---|:---:|
| `access.zoom` | `1` |  |
| `access.filter` | `"none"` |  |
| `access.text` | `1` |  |
| `access.cursor` | `0` |  |

## keybinds

Explained in [keybinds](../keybinds.md).

| Key | Default | Per screen |
|---|---|:---:|
| `keybinds` | `{}` |  |

## plugins

Explained in [plugins](../plugins/README.md).

| Key | Default | Per screen |
|---|---|:---:|
| `plugins.enabled` | `{}` |  |
| `plugins.config` | `{}` |  |

## sync

Explained in [sync](../parts/sync.md).

| Key | Default | Per screen |
|---|---|:---:|
| `sync.enabled` | `false` |  |
| `sync.targets.gtk` | `true` |  |
| `sync.targets.qt` | `true` |  |
| `sync.targets.kitty` | `true` |  |
| `sync.targets.foot` | `true` |  |
| `sync.targets.vscode` | `true` |  |
| `sync.targets.zed` | `true` |  |
| `sync.targets.neovim` | `true` |  |
| `sync.targets.firefox` | `false` |  |

## performance

Explained in [look](../look.md#motion-and-performance).

| Key | Default | Per screen |
|---|---|:---:|
| `performance` | `false` |  |

## iconTint

Explained in [look](../look.md#motion-and-performance).

| Key | Default | Per screen |
|---|---|:---:|
| `iconTint` | `true` |  |

## parts

Explained in [configuration](../configuration.md#turning-parts-off).

| Key | Default | Per screen |
|---|---|:---:|
| `parts.bar` | `true` |  |
| `parts.center` | `true` |  |
| `parts.clock` | `true` |  |
| `parts.deck` | `true` |  |
| `parts.diver` | `true` |  |
| `parts.fatest` | `true` |  |
| `parts.rgb` | `true` |  |
| `parts.media` | `true` |  |
| `parts.notify` | `true` |  |
| `parts.pad` | `true` |  |
| `parts.paper` | `true` |  |
| `parts.power` | `true` |  |
| `parts.lock` | `true` |  |
| `parts.polkit` | `true` |  |
| `parts.clip` | `true` |  |
| `parts.island` | `false` |  |
| `parts.capture` | `true` |  |
| `parts.viewer` | `true` |  |
| `parts.files` | `true` |  |
| `parts.archive` | `true` |  |
| `parts.access` | `true` |  |
| `parts.plugins` | `true` |  |
| `parts.sync` | `true` |  |
| `parts.switcher` | `true` |  |
| `parts.settings` | `true` |  |
| `parts.theme` | `true` |  |

## config.json only

These keys only make sense in `config.json` (or `programs.sylvaris.settings`), because Sylvaris never writes that file.

| Key | Default |
|---|---|
| `themesDir` | `"~/.config/sylvaris/themes"` |
| `themeHook` | `""` |
| `themeStateFile` | `"~/.local/state/sylvaris/theme"` |
| `avatar` | `"~/.face"` |
| `lockCommand` | `"loginctl lock-session"` |
| `terminal` | `"kitty"` |
| `greeterShare` | `"/var/lib/sylvaris-greet/shared"` |
| `toggles` | `[]` |
| `commands` | `[]` |
| `notifications` | `{"server":true,"history":100}` |
