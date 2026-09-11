import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enablePower ? Quickshell.screens : []
        PanelWindow {
            id: powerWindow
            property var modelData
            screen: modelData
            visible: root.powerMenuVisible && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-powermenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property int focusedIndex: 0
            readonly property var entries: [
                { label: "Lock",      icon: "󰌾", cmd: "loginctl lock-session",  clr: Theme.cyan },
                { label: "Log out",   icon: "󰍃", cmd: "hyprctl dispatch 'hl.dsp.exit()'",  clr: Theme.yellow },
                { label: "Suspend",   icon: "󰤄", cmd: "systemctl suspend",      clr: Theme.magenta },
                { label: "Hibernate", icon: "󰥹", cmd: "systemctl hibernate",    clr: Theme.blue },
                { label: "Reboot",    icon: "󰜉", cmd: "systemctl reboot",       clr: Theme.orange },
                { label: "Shut down", icon: "󰐥",  cmd: "systemctl poweroff",     clr: Theme.red },
            ]

            function activate(entry) {
                root.powerMenuVisible = false
                powerCmdProc.command = ["sh", "-c", entry.cmd]
                powerCmdProc.running = true
            }

            onVisibleChanged: if (visible) powerWindow.focusedIndex = 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.powerMenuVisible = false
                focus: true
                Keys.onEscapePressed: root.powerMenuVisible = false
                Keys.onUpPressed: powerWindow.focusedIndex = Math.max(0, powerWindow.focusedIndex - 1)
                Keys.onDownPressed: powerWindow.focusedIndex = Math.min(powerWindow.entries.length - 1, powerWindow.focusedIndex + 1)
                Keys.onReturnPressed: powerWindow.activate(powerWindow.entries[powerWindow.focusedIndex])
                Keys.onEnterPressed: powerWindow.activate(powerWindow.entries[powerWindow.focusedIndex])
            }

            PopoutFrame {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.bottomMargin: Config.gap
                width: 200
                height: powerCol.implicitHeight + 24

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: powerCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Repeater {
                        model: powerWindow.entries
                        delegate: Rectangle {
                            id: pmRow
                            required property var modelData
                            required property int index
                            // isFocused already tracks mouse hover too (see
                            // pmMA.onEntered below), so it alone drives both
                            // the row fill and label/icon color — the same
                            // "hover = fill, no border" language every other
                            // row list in the shell uses (device panels,
                            // notification rows), rather than a menu-only
                            // border style for what's the same concept.
                            readonly property bool isFocused: index === powerWindow.focusedIndex
                            Layout.fillWidth: true
                            height: 28; radius: Config.radiusCell
                            color: isFocused ? Theme.hover : "transparent"
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
                                        font.pixelSize: 13
                                        // Respect barAccentPolicy like everything
                                        // else: colorful per-action hues only
                                        // under "always"; quiet/monochrome
                                        // otherwise, matching focus like the label.
                                        color: Config.barAccentPolicy === "always"
                                            ? modelData.clr
                                            : (pmRow.isFocused ? Theme.text : Theme.subtle)
                                    }
                                }
                                Text {
                                    text: modelData.label
                                    font { family: Config.fontFamily; pixelSize: 13 }
                                    color: pmRow.isFocused ? Theme.text : Theme.subtle
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Layout.fillWidth: true
                                }
                            }
                            MouseArea {
                                id: pmMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: powerWindow.focusedIndex = index
                                onClicked: powerWindow.activate(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
