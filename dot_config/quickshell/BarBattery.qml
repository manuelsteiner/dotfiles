import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: batBlock
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: 36; radius: 6

    property var bat: UPower.displayDevice
    property real level: (bat?.percentage ?? -1) < 0 ? -1 : bat.percentage * 100
    property bool charging: {
        var s = bat?.state ?? UPowerDeviceState.Unknown
        return s === UPowerDeviceState.Charging
            || s === UPowerDeviceState.FullyCharged
    }
    property bool hasBattery: level >= 0

    property color tierColor: level < 20 ? Theme.red
                            : level < 50 ? Theme.yellow
                            : Theme.blue

    color: batMA.containsMouse
        ? (hasBattery ? tierColor : Theme.muted)
        : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: batMA.containsMouse ? Theme.base
            : batBlock.hasBattery ? batBlock.tierColor : Theme.muted
        text: {
            if (!batBlock.hasBattery) return "󱉝"
            if (batBlock.charging) {
                if (batBlock.level < 10) return "󰢜"
                if (batBlock.level < 20) return "󰢝"
                if (batBlock.level < 30) return "󰢞"
                if (batBlock.level < 40) return "󰂆"
                if (batBlock.level < 50) return "󰂇"
                if (batBlock.level < 60) return "󰂈"
                if (batBlock.level < 70) return "󰢝"
                if (batBlock.level < 80) return "󰂉"
                if (batBlock.level < 90) return "󰢞"
                return "󰂅"
            }
            if (batBlock.level < 10) return "󰁺"
            if (batBlock.level < 20) return "󰁻"
            if (batBlock.level < 30) return "󰁼"
            if (batBlock.level < 40) return "󰁽"
            if (batBlock.level < 50) return "󰁾"
            if (batBlock.level < 60) return "󰁿"
            if (batBlock.level < 70) return "󰂀"
            if (batBlock.level < 80) return "󰂁"
            if (batBlock.level < 90) return "󰂂"
            return "󰁹"
        }
    }

    MouseArea {
        id: batMA
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                var tip = ""
                if (!batBlock.hasBattery) {
                    tip = "No battery"
                } else {
                    tip = Math.round(batBlock.level) + "%"
                    if (batBlock.charging) tip += " (charging)"
                    var ttf = batBlock.bat?.timeToFull ?? 0
                    var tte = batBlock.bat?.timeToEmpty ?? 0
                    if (batBlock.charging && ttf > 0) {
                        var mf = Math.round(ttf / 60)
                        tip += "\n" + Math.floor(mf / 60) + "h " + (mf % 60) + "m to full"
                    } else if (!batBlock.charging && tte > 0) {
                        var me = Math.round(tte / 60)
                        tip += "\n" + Math.floor(me / 60) + "h " + (me % 60) + "m remaining"
                    }
                }
                root.showTooltip("bat", tip, pos.y)
            } else {
                root.hideTooltip("bat")
            }
        }
    }
}
