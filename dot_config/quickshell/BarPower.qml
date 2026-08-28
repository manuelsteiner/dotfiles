import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: 36; radius: 6
    color: powerMA.containsMouse ? Theme.powerColor : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        font.pixelSize: 18
        color: powerMA.containsMouse ? Theme.base : Theme.powerColor
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: powerMA
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            var show = !root.powerMenuVisible
            root.closeAllPanels(show ? "power" : undefined)
            root.powerMenuVisible = show
        }
    }
}
