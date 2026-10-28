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
| `displays.virtual.enabled` | `false` |  |
| `displays.virtual.width` | `2388` |  |
| `displays.virtual.height` | `1668` |  |

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
| `bar.workspaceStyle` | `"pills"` | yes |
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
| `motion.preset` | `"smooth"` |  |
| `motion.open` | `"grow"` |  |
| `motion.stagger` | `0.35` |  |
| `motion.springiness` | `-1` |  |

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
| `paper.parallax` | `0.4` |  |
| `paper.menu` | `true` |  |

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

## settings

| Key | Default | Per screen |
|---|---|:---:|
| `settings.detail` | `"simple"` |  |

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
| `files.sections` | `["places","bookmarks","devices"]` |  |
| `files.placeOrder` | `[]` |  |
| `files.deviceOrder` | `[]` |  |
| `files.details` | `false` |  |
| `files.click` | `"double"` |  |
| `files.typing` | `"filter"` |  |
| `files.start` | `"~"` |  |
| `files.confirmTrash` | `false` |  |
| `files.openArchives` | `true` |  |
| `files.bookmarks` | `[]` |  |
| `files.keys` | `{}` |  |

## widgets

| Key | Default | Per screen |
|---|---|:---:|
| `widgets.enabled` | `true` |  |
| `widgets.cell` | `80` |  |
| `widgets.gap` | `12` |  |
| `widgets.snap` | `true` |  |
| `widgets.style.material` | `"inherit"` |  |
| `widgets.style.opacity` | `1` |  |
| `widgets.style.radius` | `1` |  |
| `widgets.style.shadow` | `true` |  |
| `widgets.style.clear` | `false` |  |
| `widgets.style.accent` | `""` |  |
| `widgets.items` | `[]` |  |

## archive

| Key | Default | Per screen |
|---|---|:---:|
| `archive.view` | `"list"` |  |
| `archive.format` | `"zip"` |  |
| `archive.level` | `"normal"` |  |
| `archive.extract` | `"smart"` |  |
| `archive.reveal` | `true` |  |
| `archive.keys` | `{}` |  |

## notes

| Key | Default | Per screen |
|---|---|:---:|
| `notes.wrap` | `false` |  |
| `notes.lineNumbers` | `true` |  |
| `notes.highlight` | `true` |  |
| `notes.tabWidth` | `4` |  |
| `notes.spaces` | `true` |  |
| `notes.size` | `14` |  |
| `notes.recent` | `[]` |  |

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

## temp

| Key | Default | Per screen |
|---|---|:---:|
| `temp.interval` | `1` |  |
| `temp.overlay.show` | `"off"` |  |
| `temp.overlay.apps` | `[]` |  |
| `temp.overlay.corner` | `"top-left"` |  |
| `temp.overlay.x` | `16` |  |
| `temp.overlay.y` | `16` |  |
| `temp.overlay.scale` | `1` |  |
| `temp.overlay.opacity` | `0.85` |  |
| `temp.overlay.style` | `"compact"` |  |
| `temp.alerts` | `true` |  |
| `temp.cooldown` | `300` |  |
| `temp.pinned` | `[]` |  |

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
| `placement.temp` | `"top-right"` | yes |

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
| `performance` | `"auto"` |  |

## iconTint

Explained in [look](../look.md#motion-and-performance).

| Key | Default | Per screen |
|---|---|:---:|
| `iconTint` | `true` |  |

## look

Explained in [look](../look.md#looks).

| Key | Default | Per screen |
|---|---|:---:|
| `look.preset` | `"lumen"` |  |
| `look.followTheme` | `false` |  |
| `look.parts` | `{}` |  |

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
| `parts.temp` | `true` |  |
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
| `parts.widgets` | `true` |  |
| `parts.archive` | `true` |  |
| `parts.notes` | `true` |  |
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
