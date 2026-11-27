import QtQuick
import SylStack
import qs.services

Column {
    id: page

    required property var host

    spacing: 24

    Card {
        title: "Statistics"

        StatsAbout {
            width: parent.width
            topPadding: 12
            version: page.host.version
            memory: page.host.memory
            uptime: page.host.uptimeText
            onReload: Stack.reload(false)
        }
    }

    Card {
        title: "Constellation"
        visible: Settings.shown.settings.home === "constellation"

        ConstellationControls {
            width: parent.width
            topPadding: 12
        }
    }
}
