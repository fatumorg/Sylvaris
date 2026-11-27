import QtQuick
import qs.services
import qs.components

Segmented {
    width: 330
    options: [
        { key: "sidebar", label: "Sidebar" },
        { key: "cards", label: "Cards" },
        { key: "constellation", label: "Constellation" }
    ]
    current: Settings.shown.settings.home
    onPicked: key => Settings.put("settings.home", key)
}
