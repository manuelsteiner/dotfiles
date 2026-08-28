import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: brightBlock
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: Config.enableBrightnessBar ? 42 : 36; radius: 6
    property real bright: root.brightOsdValue
    color: brightMA.containsMouse ? Theme.brightnessColor : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Config.enableBrightnessBar ? -4 : 0
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: brightMA.containsMouse ? Theme.base : Theme.brightnessColor
        text: brightBlock.bright < 0.33 ? "󰃞"
            : brightBlock.bright < 0.66 ? "󰃟" : "󰃠"
    }

    // Brightness level bar (toggle via Config.enableBrightnessBar)
    Rectangle {
        visible: Config.enableBrightnessBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        width: 24; height: 3; radius: 1.5
        color: brightMA.containsMouse ? Theme.highlightMed
            : Theme.highlightMed
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            width: parent.width * Math.min(brightBlock.bright, 1.0)
            height: parent.height; radius: parent.radius
            color: brightMA.containsMouse ? Theme.base : Theme.brightnessColor
            Behavior on width { NumberAnimation { duration: 80 } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }

    MouseArea {
        id: brightMA
        anchors.fill: parent
        hoverEnabled: true
        onWheel: wheel => {
            var step = 5
            if (wheel.angleDelta.y > 0)
                brightSetProc.command = ["brightnessctl", "set", step + "%+"]
            else if (wheel.angleDelta.y < 0)
                brightSetProc.command = ["brightnessctl", "set", step + "%-"]
            else return
            brightSetProc.running = true
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.showTooltip("bright",
                    Math.round(brightBlock.bright * 100) + "%", pos.y)
            } else {
                root.hideTooltip("bright")
            }
        }
    }

    Process { id: brightSetProc; running: false }
}
