import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Column {
    id: trayColumn
    Layout.alignment: Qt.AlignHCenter
    spacing: 4
    property var screen: null

    Repeater {
        model: SystemTray.items
        delegate: BarCell {
            required property SystemTrayItem modelData
            required property int index
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            hovered: trayMA.containsMouse
            pressed: trayMA.pressed
            active: false
            urgent: false
            Image {
                id: trayIcon
                anchors.centerIn: parent
                source: modelData.icon
                width: 18; height: 18
                sourceSize.width: 18; sourceSize.height: 18
                opacity: Config.trayIconStyle === "dim"
                    ? (trayMA.containsMouse ? 1.0 : 0.75) : 1.0
                layer.enabled: Config.trayIconStyle === "desaturate"
                layer.effect: MultiEffect {
                    saturation: trayMA.containsMouse ? 0 : -1
                }
            }
            MouseArea {
                id: trayMA
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                            var pos = parent.mapToItem(null, 0, parent.height / 2)
                            root.openTrayMenu(modelData.menu, pos.y, trayColumn.screen)
                        } else {
                            modelData.secondaryActivate()
                        }
                    } else {
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            var pos2 = parent.mapToItem(null, 0, parent.height / 2)
                            root.openTrayMenu(modelData.menu, pos2.y, trayColumn.screen)
                        } else {
                            modelData.activate()
                        }
                    }
                }
                onContainsMouseChanged: {
                    if (containsMouse) {
                        var pos = parent.mapToItem(null, 0, parent.height / 2)
                        root.showTooltip("tray-" + index,
                            modelData.tooltipTitle || modelData.title, pos.y)
                    } else {
                        root.hideTooltip("tray-" + index)
                    }
                }
            }
        }
    }
}
