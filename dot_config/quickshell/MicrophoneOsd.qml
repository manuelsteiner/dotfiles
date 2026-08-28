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

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Config.effectiveBarWidth + Config.barGap
                y: Config.osdPosition === "top" ? Config.barGap
                    : Config.osdPosition === "bottom" ? parent.height - height - Config.barGap
                    : Math.round((parent.height - height) / 2)
                width: 50; height: 200; radius: 12
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2
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
                        Rectangle { anchors.fill: parent; radius: 4; color: Theme.highlightMed }
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
                        font.pixelSize: 12; font.bold: true
                        color: root.micOsdMuted ? Theme.muted : Theme.text
                    }
                }
            }
        }
    }
}
