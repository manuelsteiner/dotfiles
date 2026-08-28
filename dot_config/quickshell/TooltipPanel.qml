import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.tooltipVisible && root.tooltipText !== ""
            WlrLayershell.namespace: "qs-tooltip"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true }
            implicitWidth: 300
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: Math.max(Config.barGap, Math.min(
                    parent.height - height - Config.barGap,
                    root.tooltipY - height / 2
                ))
                width: tipText.implicitWidth + 20
                height: tipText.implicitHeight + 12
                radius: 6
                color: Theme.overlay
                border.color: Theme.highlightMed
                border.width: 1
                Text {
                    id: tipText
                    anchors.centerIn: parent
                    text: root.tooltipText
                    font { family: Config.fontFamily; pixelSize: 12 }
                    color: Theme.text
                }
            }
        }
    }
}
