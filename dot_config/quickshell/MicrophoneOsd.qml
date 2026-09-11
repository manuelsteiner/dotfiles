import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableMicrophoneOsd ? Quickshell.screens : []
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.micOsdVisible
            WlrLayershell.namespace: "qs-mic-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true }
            implicitWidth: 120
            color: "transparent"

            PopoutFrame {
                anchors.left: parent.left
                anchors.leftMargin: Config.effectiveBarWidth + Config.gap
                // "top" matches the bar's own top gap so the OSD's top edge
                // lines up with the bar islands' top edge, not the tighter
                // screen-edge inset toasts use.
                y: Config.osdPosition === "top" ? Config.gap
                    : Config.osdPosition === "bottom" ? parent.height - height - Config.edgeInset
                    : Math.round((parent.height - height) / 2)
                width: 56; height: 200
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Config.fontFamily
                        font.pixelSize: 20
                        color: root.micOsdMuted ? Theme.muted : Theme.microphoneColor
                        text: root.micOsdMuted ? "󰍭" : "󰍬"
                    }
                    Item {
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        width: 8
                        Rectangle { anchors.fill: parent; radius: 4; color: Theme.divider }
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: parent.height * Math.min(1, root.micOsdValue)
                            radius: 4
                            color: root.micOsdMuted ? Theme.muted : Theme.microphoneColor
                            Behavior on height { NumberAnimation { duration: 80 } }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(root.micOsdValue * 100)
                        font.pixelSize: 11; font.bold: true
                        font.features: { "tnum": 1 }
                        color: root.micOsdMuted ? Theme.muted : Theme.text
                    }
                }
            }
        }
    }
}
