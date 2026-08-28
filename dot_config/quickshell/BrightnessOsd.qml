import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Process {
        id: brightWatcher
        command: ["sh", "-c",
            "stdbuf -oL udevadm monitor --kernel --subsystem-match=backlight 2>/dev/null"
            + " | while read -r line; do"
            + "   case \"$line\" in *change*)"
            + "     brightnessctl -m info 2>/dev/null | head -1;;"
            + "   esac;"
            + " done"]
        running: Config.enableBrightnessOsd
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(",")
                if (parts.length >= 4) {
                    var pct = parseInt(parts[3])
                    if (!isNaN(pct)) {
                        root.brightOsdValue = pct / 100.0
                        if (root._osdReady && root._brightInitialized) {
                            root.brightOsdVisible = true
                            brightOsdHideTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Process {
        id: brightInitProc
        command: ["brightnessctl", "-m", "info"]
        running: Config.enableBrightnessOsd
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(",")
                if (parts.length >= 4) {
                    var pct = parseInt(parts[3])
                    if (!isNaN(pct)) root.brightOsdValue = pct / 100.0
                }
            }
        }
        onExited: root._brightInitialized = true
    }

    Variants {
        model: Config.enableBrightnessOsd ? Quickshell.screens : []
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.brightOsdVisible
            WlrLayershell.namespace: "qs-bright-osd"
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
                        color: Theme.brightnessColor
                        text: root.brightOsdValue < 0.33 ? "󰃞"
                            : root.brightOsdValue < 0.66 ? "󰃟" : "󰃠"
                    }
                    Item {
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        width: 8
                        Rectangle { anchors.fill: parent; radius: 4; color: Theme.highlightMed }
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: parent.height * Math.min(1, root.brightOsdValue)
                            radius: 4; color: Theme.brightnessColor
                            Behavior on height { NumberAnimation { duration: 80 } }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(root.brightOsdValue * 100)
                        font.pixelSize: 12; font.bold: true; color: Theme.text
                    }
                }
            }
        }
    }
}
