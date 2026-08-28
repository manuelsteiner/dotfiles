import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableMicrophonePanel ? Quickshell.screens : []
        PanelWindow {
            id: micPanelWindow
            property var modelData
            screen: modelData
            visible: root.micPanelVisible
            WlrLayershell.namespace: "qs-micpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            PwObjectTracker {
                id: sourceTracker
                objects: {
                    var result = []
                    for (var i = 0; i < Pipewire.nodes.count; i++)
                        result.push(Pipewire.nodes.values[i])
                    return result
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.micPanelVisible = false
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: Math.max(Config.barGap, Math.min(
                    parent.height - height - Config.barGap,
                    root.micPanelY - 18
                ))
                width: 260
                height: panelCol.implicitHeight + 24
                radius: 12
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: panelCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Audio Input"
                        font { family: Config.fontFamily; pixelSize: 14; bold: true }
                        color: Theme.text
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.highlightMed }

                    // Default source (on top)
                    Repeater {
                        model: Pipewire.nodes
                        delegate: MicNodeDelegate {
                            required property var modelData
                            node: modelData
                            isDefault: modelData === Pipewire.defaultAudioSource
                            visible: !modelData.isSink && !modelData.isStream && modelData.audio && isDefault
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            onSetDefault: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }

                    // Other sources
                    Repeater {
                        model: Pipewire.nodes
                        delegate: MicNodeDelegate {
                            required property var modelData
                            node: modelData
                            isDefault: modelData === Pipewire.defaultAudioSource
                            visible: !modelData.isSink && !modelData.isStream && modelData.audio && !isDefault
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            onSetDefault: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                }
            }
        }
    }

    component MicNodeDelegate: Rectangle {
        id: del
        property var node
        property bool isDefault: false
        property real nodeVol: node.audio?.volume || 0
        property bool nodeMuted: node.audio?.muted ?? false
        signal setDefault()

        implicitHeight: visible ? col.height + 16 : 0
        radius: 8
        color: isDefault ? Theme.overlay
            : ma.containsMouse ? Theme.highlightMed : "transparent"
        border.color: isDefault ? Theme.microphoneColor : "transparent"
        border.width: isDefault ? 1 : 0
        Behavior on color { ColorAnimation { duration: 80 } }

        Column {
            id: col
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 6

            Item {
                width: parent.width; height: 18

                Item {
                    id: iconWrap
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: del.nodeMuted ? "󰍭" : "󰍬"
                        font { family: Config.fontFamily; pixelSize: 14 }
                        color: del.isDefault ? Theme.microphoneColor
                            : del.nodeMuted ? Theme.muted : Theme.subtle
                    }
                }

                Text {
                    anchors.left: iconWrap.right; anchors.leftMargin: 8
                    anchors.right: volText.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: del.node.description || del.node.name || "Unknown"
                    font { family: Config.fontFamily; pixelSize: 12 }
                    color: del.isDefault || ma.containsMouse ? Theme.text : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 80 } }
                    elide: Text.ElideRight
                }

                Text {
                    id: volText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(del.nodeVol * 100) + "%"
                    font { family: Config.fontFamily; pixelSize: 11 }
                    color: del.nodeMuted ? Theme.muted : Theme.subtle
                }
            }

            Rectangle {
                width: parent.width; height: 4; radius: 2
                color: ma.containsMouse ? Theme.highlightHigh : Theme.highlightMed
                Rectangle {
                    width: parent.width * Math.min(del.nodeVol, 1.0)
                    height: parent.height; radius: parent.radius
                    color: del.isDefault ? Theme.microphoneColor
                        : del.nodeMuted ? Theme.muted : Theme.subtle
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (del.node.audio)
                        del.node.audio.muted = !del.node.audio.muted
                } else if (!del.isDefault) {
                    del.setDefault()
                }
            }
            onWheel: wheel => {
                if (!del.node.audio) return
                var step = 0.05
                if (wheel.angleDelta.y > 0)
                    del.node.audio.volume = Math.min(del.node.audio.volume + step, 1.0)
                else if (wheel.angleDelta.y < 0)
                    del.node.audio.volume = Math.max(del.node.audio.volume - step, 0.0)
            }
        }
    }
}
