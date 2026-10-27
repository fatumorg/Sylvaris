pragma Singleton

import QtQuick
import SylStack

Singleton {
    readonly property bool enabled: Stack.env("SYLVARIS_DEMO") === "1"

    readonly property var bluetooth: [
        { address: "00:11:22:33:44:01", name: "Headphones", icon: "audio-headphones", connected: true, paired: true, trusted: true, batteryAvailable: true, battery: 0.9 },
        { address: "00:11:22:33:44:02", name: "Mouse", icon: "input-mouse", connected: true, paired: true, trusted: true, batteryAvailable: true, battery: 0.7 },
        { address: "00:11:22:33:44:03", name: "Controller", icon: "input-gaming", connected: false, paired: true, trusted: false, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:04", name: "Phone", icon: "phone", connected: false, paired: false, trusted: false, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:05", name: "Earbuds", icon: "audio-headset", connected: false, paired: true, trusted: true, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:06", name: "A device with a remarkably long Bluetooth name that must not overflow", icon: "computer", connected: false, paired: false, trusted: false, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:07", name: "Speaker", icon: "audio-card", connected: false, paired: false, trusted: false, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:08", name: "Keyboard", icon: "input-keyboard", connected: false, paired: false, trusted: false, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:09", name: "Tablet", icon: "input-tablet", connected: false, paired: false, trusted: false, batteryAvailable: false, battery: 0 },
        { address: "00:11:22:33:44:0A", name: "Watch", icon: "watch", connected: false, paired: false, trusted: false, batteryAvailable: false, battery: 0 }
    ]

    readonly property var wifi: [
        { name: "Home_5G", signal: 0.92, security: "Wpa2Psk", open: false, connected: true, known: true },
        { name: "Home_2.4", signal: 0.8, security: "Wpa2Psk", open: false, connected: false, known: true },
        { name: "Cafe", signal: 0.55, security: "Open", open: true, connected: false, known: false },
        { name: "Neighbour", signal: 0.3, security: "Sae", open: false, connected: false, known: false },
        { name: "PLAY_Free", signal: 0.2, security: "Open", open: true, connected: false, known: false }
    ]

    readonly property var sinks: [
        { id: 1, description: "Headphones" },
        { id: 2, description: "Speakers" },
        { id: 3, description: "HDMI Display" }
    ]

    readonly property var streams: [
        { id: 11, app: "Firefox", volume: 0.8 },
        { id: 12, app: "Spotify", volume: 0.45 }
    ]

    readonly property var player: ({ identity: "Music", title: "Evening Walk", artist: "The Example Band", art: "", playing: true })

    readonly property var outputs: [
        { name: "DP-1", description: "Example Monitor A (DP-1)", enabled: true, position: { x: 0, y: 500 }, scale: 1.0, transform: "normal", modes: [
                { width: 1920, height: 1080, refresh: 179.964, preferred: false, current: true },
                { width: 1920, height: 1080, refresh: 60.0, preferred: true, current: false }
            ] },
        { name: "DP-2", description: "Example Monitor B (DP-2)", enabled: true, position: { x: 1920, y: 0 }, scale: 1.0, transform: "normal", modes: [
                { width: 2560, height: 1440, refresh: 200.013, preferred: false, current: true },
                { width: 2560, height: 1440, refresh: 59.951, preferred: true, current: false }
            ] },
        { name: "HDMI-A-1", description: "Example TV (HDMI-A-1)", enabled: false, modes: [
                { width: 1920, height: 1080, refresh: 60.0, preferred: true, current: false }
            ] }
    ]

    readonly property var apps: [
        { id: "firefox", name: "Firefox", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "kitty", name: "Kitty", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "files", name: "Files", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "steam", name: "Steam", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "spotify", name: "Spotify", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "discord", name: "Discord", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "visual-studio-code", name: "Visual Studio Code", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "gimp", name: "GIMP", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "blender", name: "Blender", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "calculator", name: "Calculator", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "calendar", name: "Calendar", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "clocks", name: "Clocks", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "maps", name: "Maps", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "weather", name: "Weather", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "photos", name: "Photos", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "music", name: "Music", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "videos", name: "Videos", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "text-editor", name: "Text Editor", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "settings", name: "Settings", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "system-monitor", name: "System Monitor", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "disks", name: "Disks", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "fonts", name: "Fonts", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "characters", name: "Characters", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "contacts", name: "Contacts", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "obsidian", name: "Obsidian", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "thunderbird", name: "Thunderbird", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "libreoffice-writer", name: "LibreOffice Writer", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "libreoffice-calc", name: "LibreOffice Calc", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "inkscape", name: "Inkscape", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "krita", name: "Krita", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "obs-studio", name: "OBS Studio", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "vlc", name: "VLC", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "transmission", name: "Transmission", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "signal", name: "Signal", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "telegram", name: "Telegram", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "zoom", name: "Zoom", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "heroic", name: "Heroic", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "lutris", name: "Lutris", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "bottles", name: "Bottles", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "remmina", name: "Remmina", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "virt-manager", name: "Virt Manager", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false },
        { id: "wireshark", name: "Wireshark", genericName: "", comment: "", keywords: [], icon: "", noDisplay: false, runInTerminal: false }
    ]

    readonly property var windows: [
        { appId: "firefox", title: "Sylvaris — Mozilla Firefox", activated: true, minimized: false, fullscreen: false, handle: null },
        { appId: "kitty", title: "~/NixOS", activated: false, minimized: false, fullscreen: false, handle: null },
        { appId: "kitty", title: "htop", activated: false, minimized: false, fullscreen: false, handle: null },
        { appId: "spotify", title: "Spotify", activated: false, minimized: false, fullscreen: false, handle: null }
    ]

    readonly property var cards: [
        { name: "bluez_card.00_11_22_33_44_01", active_profile: "a2dp-sink", profiles: {
                "a2dp-sink": { available: true },
                "headset-head-unit": { available: true }
            } }
    ]
}
