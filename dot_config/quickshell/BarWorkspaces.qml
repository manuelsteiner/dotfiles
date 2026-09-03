import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: wsColumn.implicitWidth
    implicitHeight: wsColumn.implicitHeight

    property bool bgStyle: Config.workspaceStyle === "background"

    property int activeIndex: {
        for (var i = 0; i < Config.workspaces.length; i++) {
            var ws = Config.workspaces[i].ws
            if (Hyprland.workspaces.values.some(w => w.id === ws && w.focused))
                return i
        }
        return 0
    }

    property bool activeHovered: false

    // Sliding accent background (only in "background" style)
    Rectangle {
        id: highlight
        visible: bgStyle
        width: 36; height: 36; radius: 6
        color: activeHovered ? Theme.accentDim : Theme.accent
        Behavior on color { ColorAnimation { duration: 80 } }
        x: wsColumn.x + (wsColumn.width - width) / 2
        y: activeIndex * (36 + 4)

        Behavior on y {
            enabled: Config.enableWorkspaceTransition
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Column {
        id: wsColumn
        spacing: 4

        Repeater {
            id: wsRepeater
            model: Config.workspaces
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: 36; height: 36; radius: 6
                property bool active: index === activeIndex
                property bool hovered: wsMA.containsMouse
                property bool urgent: Hyprland.workspaces.values.some(w => w.id === modelData.ws && w.urgent)
                color: wsMA.containsMouse
                    ? (bgStyle ? (active ? "transparent" : Theme.accent)
                               : Theme.accent)
                    : (bgStyle && urgent && !active ? Theme.urgentColor : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    font.family: Config.fontFamily
                    font.pixelSize: 18
                    color: bgStyle
                        ? (parent.active ? Theme.base
                            : wsMA.containsMouse ? Theme.base
                            : parent.urgent ? Theme.base
                            : Theme.muted)
                        : (wsMA.containsMouse ? Theme.base
                            : parent.active ? Theme.accent
                            : parent.urgent ? Theme.urgentColor
                            : Theme.muted)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: wsMA
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = ' + parent.modelData.ws + ' })')
                    onContainsMouseChanged: {
                        if (parent.active) activeHovered = containsMouse
                    }
                }
            }
        }
    }
}
