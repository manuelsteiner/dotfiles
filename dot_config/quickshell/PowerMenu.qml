import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enablePower ? Quickshell.screens : []
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.powerMenuVisible
            WlrLayershell.namespace: "qs-powermenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.powerMenuVisible = false
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottomMargin: Config.barGap
                width: 200
                height: powerCol.implicitHeight + 24
                radius: 12
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: powerCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "Lock",      icon: "󰌾", cmd: "loginctl lock-session",  clr: Theme.foam },
                            { label: "Log out",   icon: "󰍃", cmd: "hyprctl dispatch 'hl.dsp.exit()'",  clr: Theme.gold },
                            { label: "Suspend",   icon: "󰤄", cmd: "systemctl suspend",      clr: Theme.iris },
                            { label: "Hibernate", icon: "󰥹", cmd: "systemctl hibernate",    clr: Theme.pine },
                            { label: "Reboot",    icon: "󰜉", cmd: "systemctl reboot",       clr: Theme.rose },
                            { label: "Shut down", icon: "󰐥",  cmd: "systemctl poweroff",     clr: Theme.love },
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 36; radius: 6
                            color: pmMA.containsMouse ? Theme.highlightMed : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 0
                                Item {
                                    width: 28; height: parent.height
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: Config.fontFamily
                                        font.pixelSize: 16
                                        color: modelData.clr
                                    }
                                }
                                Text {
                                    text: modelData.label
                                    font { family: Config.fontFamily; pixelSize: 13 }
                                    color: pmMA.containsMouse ? Theme.text : Theme.subtle
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Layout.fillWidth: true
                                }
                            }
                            MouseArea {
                                id: pmMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.powerMenuVisible = false
                                    powerCmdProc.command = ["sh", "-c", modelData.cmd]
                                    powerCmdProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
