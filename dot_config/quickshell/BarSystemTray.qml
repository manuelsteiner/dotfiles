import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

Column {
    Layout.alignment: Qt.AlignHCenter
    spacing: 4

    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            required property SystemTrayItem modelData
            required property int index
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            width: 36; height: 36; radius: 6
            color: trayMA.containsMouse ? Theme.highlightLow : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Image {
                anchors.centerIn: parent
                source: modelData.icon
                width: 18; height: 18
                sourceSize.width: 18; sourceSize.height: 18
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
                            root.openTrayMenu(modelData.menu, pos.y)
                        } else {
                            modelData.secondaryActivate()
                        }
                    } else {
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            var pos2 = parent.mapToItem(null, 0, parent.height / 2)
                            root.openTrayMenu(modelData.menu, pos2.y)
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
