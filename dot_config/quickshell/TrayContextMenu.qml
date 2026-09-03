import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableSystemTray ? Quickshell.screens : []
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.trayMenuVisible && root.trayMenuHandle !== null
            WlrLayershell.namespace: "qs-traymenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            QsMenuOpener {
                id: menuOpener
                menu: root.trayMenuHandle
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.closeTrayMenu()
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: Math.max(Config.barGap, Math.min(
                    parent.height - height - Config.barGap,
                    root.trayMenuY - 18
                ))
                width: menuCol.implicitWidth + 24
                height: menuCol.implicitHeight + 16
                radius: 8
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: menuCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Repeater {
                        model: menuOpener.children

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.minimumWidth: 160
                            visible: modelData.enabled || modelData.isSeparator
                            height: modelData.isSeparator ? 9 : 28
                            radius: 4
                            color: !modelData.isSeparator && miMA.containsMouse
                                ? Theme.highlightMed : "transparent"
                            Behavior on color { ColorAnimation { duration: 60 } }

                            Rectangle {
                                visible: modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: 1
                                color: Theme.highlightMed
                            }

                            RowLayout {
                                visible: !modelData.isSeparator
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    visible: modelData.buttonType !== 0
                                    font.family: Config.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.magenta
                                    text: modelData.checkState > 0
                                        ? (modelData.buttonType === 1 ? "󰄵" : "󰄮")
                                        : (modelData.buttonType === 1 ? "󰄱" : "󰄯")
                                    Layout.preferredWidth: 16
                                }

                                Text {
                                    text: modelData.text ?? ""
                                    font { family: Config.fontFamily; pixelSize: 12 }
                                    color: modelData.enabled
                                        ? (miMA.containsMouse ? Theme.text : Theme.subtle)
                                        : Theme.muted
                                    Behavior on color { ColorAnimation { duration: 60 } }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: modelData.hasChildren
                                    text: "›"
                                    font.pixelSize: 14
                                    color: Theme.muted
                                }
                            }

                            MouseArea {
                                id: miMA
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !modelData.isSeparator && modelData.enabled
                                onClicked: {
                                    if (!modelData.hasChildren) {
                                        modelData.triggered()
                                        root.closeTrayMenu()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
