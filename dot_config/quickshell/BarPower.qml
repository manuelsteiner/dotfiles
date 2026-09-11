import Quickshell
import QtQuick
import QtQuick.Layouts

BarCell {
    id: powerBlock
    Layout.alignment: Qt.AlignHCenter
    property var screen: null
    hovered: powerMA.containsMouse
    pressed: powerMA.pressed
    active: Config.barAccentPolicy === "always"
    urgent: false
    accentColor: Theme.powerColor

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        font.pixelSize: 18
        color: powerBlock.glyphColor
    }

    MouseArea {
        id: powerMA
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.togglePowerMenu(powerBlock.screen)
    }
}
