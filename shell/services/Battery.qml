pragma Singleton

import QtQuick
import SylStack
import "../lib/power.mjs" as P

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: root.device !== null && root.device.ready && root.device.isLaptopBattery
    readonly property int percent: !root.present ? 100 : Math.round(root.device.percentage > 1 ? root.device.percentage : root.device.percentage * 100)
    readonly property bool discharging: root.present && root.device.state === UPowerDeviceState.Discharging
    property int warned: 101

    function check(): void {
        const a = P.batteryAlert(root.percent, root.discharging, root.warned);
        root.warned = a.warned;
        if (a.warn > 0 && !Demo.enabled)
            Stack.execDetached(["notify-send", "-a", "Sylvaris", "-u", a.warn <= 5 ? "critical" : "normal", "-i", "battery-caution", "Battery at " + root.percent + "%", a.warn <= 5 ? "Plug in the charger now or save your work" : "Plug in the charger soon"]);
    }

    onPercentChanged: root.check()
    onDischargingChanged: root.check()
}
