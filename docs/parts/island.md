# SylIsland

A pill on your screen that shows what is going on right now, and turns into controls when you hover it. It is off by default:

```sh
sylvaris set parts.island true
```

## What it shows

One thing at a time in the pill, with a second one as a small bubble beside it. Hover the island (or click it) and every activity gets its own row with its own buttons, so you can stop a recording and skip a song side by side.

| Activity | Row | Buttons |
|---|---|---|
| Calls | caller and app, pinned on top until the app ends the call | decline, answer |
| Voice chats | the app and how long you have been talking, while a chat app or a browser uses your microphone | mute your microphone, open the app |
| Short alerts | volume changes, a Bluetooth device connecting (with its battery), messages, notifications if you want them, switches changing (do not disturb, night light, performance mode, Wi-Fi, Bluetooth, privacy mode going off, the network connecting or dropping), text from your scripts | depends on the alert |
| Screen recording | elapsed time | stop |
| Privacy mode | "Mic and cameras off", with the key that undoes it, while [`sylvaris privacy`](../commands.md) is on | turn them back on |
| Microphone and camera | the apps using your microphone or a camera right now, other than a voice chat already shown | privacy mode |
| Diver | alarms, focus timers, and tasks starting within 15 minutes | snooze, done, end focus |
| Music and video | title, artist, artwork and a seek bar, from any MPRIS player | previous, play or pause, next |

Paused music stays in the island with a play button until its player closes, so you can pick up where you left off without opening the player. `island.keepPaused = false` hides it again.

Click a row to open the matching panel. Panels opened from the island, by a row or a shortcut, grow out of it and dock right under it instead of opening in their usual corner, and the island stays open above them, as if you were hovering it, with the panel attached right below. Scroll anywhere on the island to change the volume. Right-click the pill to open the panel for what it shows.

## Messages and calls

The island recognises messages and calls from the notifications these apps send: Discord and its clients (Vesktop, Vencord, WebCord, Legcord, Equibop, Dorion), Signal, Telegram and its forks (AyuGram, Kotatogram, 64Gram), WhatsApp (ZapZap, Whatsie, Karere), Messenger (Caprine), Instagram, Slack, Teams, Matrix apps (Element, SchildiChat, Fractal, Nheko, Cinny, NeoChat, FluffyChat), Zoom, Mattermost, Rocket.Chat, Zulip, Wire, Session, SimpleX, Threema, Viber, Beeper, XMPP apps (Dino, Gajim), Ferdium, your phone through KDE Connect or GSConnect, and mail from Thunderbird, Betterbird, Geary, Evolution, Mailspring and KMail. Web versions in a browser count too: web.whatsapp.com, messenger.com, discord.com, web.telegram.org, Slack, Teams, Element, Instagram and facetime.apple.com.

A message row shows the sender, the text and their picture (or the app's icon), with buttons to reply, mark as read, open the app and dismiss. Reply only appears when the app accepts replies from a notification; Telegram does, Discord does not. Ferdium sends everything as "Ferdium", so the island cannot tell which service inside it wrote.

FaceTime has no Linux app. Only FaceTime calls opened at facetime.apple.com in a browser can show up.

Messages and calls taken by the island skip the usual toasts.

A voice chat you are already in sends no notification, so the island watches for a chat app (or a browser, for Meet and the web versions) recording from your microphone instead. The timer belongs to the app, not to one stream: when the app reconnects its microphone or opens a second stream, the count goes on, and a call that drops for under 10 seconds keeps its time. The mute button mutes every microphone stream of that app in PipeWire, so it works the same in every app; the app's own mute button may not show it. `calls` turns voice chats off along with incoming calls.

While a call rings or a voice chat is going, the island stays out on top: it does not tuck away in hover mode, and it shows over full-screen apps and games. `island.pinCalls = false` lets it behave as usual during calls.

## Microphone and camera

An app shows up only while one of its PipeWire streams is linked to a real microphone; sound captured from your speakers, such as a visualiser or a screen recorder taking desktop audio, does not count, and neither do volume meters. Apps are named by what they are rather than by their stream: helper streams of GPU Screen Recorder show as GPU Screen Recorder, Discord's "WEBRTC VoiceEngine" as Discord, and plumbing that PipeWire or PulseAudio modules create on their own is left out. Cameras show up from their PipeWire streams and from any process holding a `/dev/video*` device, checked every 3 seconds. Privacy mode replaces that row, since nothing can use them then. `island.privacy = false` hides both; `island.status = false` hides the switch alerts.

## Shortcuts

The expanded island ends with a row of up to eight buttons. Panels close the island when you press them; switches stay and light up while they are on.

`notify` (with the number of notifications), `center`, `media`, `clock`, `pad`, `clip`, `screenshot`, `record` (stops a running recording), `dnd`, `wifi`, `bluetooth`, `night`, `settings`, `power`, `lock`.

```sh
sylvaris set island.shortcuts '["notify","center","dnd","wifi"]'
sylvaris island run dnd
```

## Where it sits

`island.position` takes `top-left`, `top-center`, `top-right`, `bottom-left`, `bottom-center` or `bottom-right`. `island.screens` shows it on the `focused` screen only or on `all` screens, each with its own island that expands on its own. Position, visibility, idle look and shortcuts can differ per screen.

`island.reveal` is `always` to keep the island on screen, or `hover` to tuck it into the edge like SylDeck: a short line marks where it is, and pushing the pointer against the edge slides it out. Incoming calls and short alerts still slide out on their own while it is tucked.

When nothing is going on, `island.idle` decides: `hide` it, keep a small `pill` so your shortcuts are one hover away, or show a `clock`. The pill and the clock also show your unread notification count and whether do not disturb is on. The island hides while a panel opens in the same spot, and it sits under fullscreen windows.

## Sites it ignores

Media from the sites in `island.hideSites` stays out of the island, so a YouTube video does not take it over. The default list is `youtube.com` and `youtu.be`; YouTube Music (music.youtube.com) still shows. The bar and SylMedia still show everything.

## From scripts

```sh
sylvaris island show "Backup finished"   # a short alert with your text
sylvaris island answer                   # also: decline
sylvaris island mute                     # mute or unmute your mic in the voice chat
sylvaris island reply "on my way"        # reply to the message on screen
sylvaris island reply                    # open the reply box for it, handy on a key
sylvaris island open                     # also: close, toggle, state
```

## Settings

| Key (`island.`) | Default | Meaning |
|---|---|---|
| `media`, `recording`, `diver`, `volume`, `devices`, `messages`, `calls` | `true` | which activities show |
| `notifications` | `false` | show every notification in the island instead of as a toast |
| `keepPaused` | `true` | keep paused music |
| `hover` | `true` | expand on hover; otherwise click |
| `seconds` | `5` | how long short alerts stay, 1 to 10 (messages stay 5 seconds longer); hovering the island holds them |
| `position` | `top-center` | see above |
| `screens` | `focused` | `focused` or `all` |
| `reveal` | `always` | `always`, or `hover` to tuck it into the edge until you point at it |
| `idle` | `pill` | `hide`, `pill` or `clock` |
| `shortcuts` | `["notify","center","media","screenshot","record","dnd"]` | up to 8 |
| `hideSites` | `["youtube.com","youtu.be"]` | up to 20 sites |
