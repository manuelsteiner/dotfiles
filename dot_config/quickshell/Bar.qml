import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData
            WlrLayershell.namespace: "qs-bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Auto
            anchors { top: true; bottom: true; left: true }
            implicitWidth: Config.effectiveBarWidth
            color: Config.barIslands ? "transparent" : Theme.base

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Config.barGap
                anchors.bottomMargin: Config.barGap
                anchors.leftMargin: Config.barIslands ? Config.barGap : 0
                anchors.rightMargin: 0
                spacing: Config.barIslands ? Config.barGap : 4

                // ── Clock island ──
                Rectangle {
                    visible: Config.enableClock
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.preferredHeight: clockItem.implicitHeight + (Config.barIslands ? 12 : 0)
                    radius: Config.barIslands ? 6 : 0
                    color: Config.barIslands ? Theme.surface : "transparent"

                    BarClock {
                        id: clockItem
                        anchors.centerIn: parent
                        width: parent.width
                    }
                }

                BarSeparator { visible: !Config.barIslands && Config.enableClock && Config.enableWorkspaces }

                // ── Workspaces island ──
                Rectangle {
                    visible: Config.enableWorkspaces
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.preferredHeight: wsItem.implicitHeight + (Config.barIslands ? 12 : 0)
                    radius: Config.barIslands ? 6 : 0
                    color: Config.barIslands ? Theme.surface : "transparent"

                    BarWorkspaces {
                        id: wsItem
                        anchors.centerIn: parent
                    }
                }

                BarSeparator { visible: !Config.barIslands && Config.enableWorkspaces }

                Item { Layout.fillHeight: true }

                BarSeparator { visible: !Config.barIslands }

                // ── System tray island ──
                Rectangle {
                    visible: Config.enableSystemTray && barTray.height > 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.preferredHeight: barTray.implicitHeight + (Config.barIslands ? 12 : 0)
                    radius: Config.barIslands ? 6 : 0
                    color: Config.barIslands ? Theme.surface : "transparent"

                    BarSystemTray {
                        id: barTray
                        anchors.centerIn: parent
                    }
                }

                BarSeparator { visible: !Config.barIslands && Config.enableSystemTray && barTray.height > 0 }

                // ── Status island ──
                Rectangle {
                    id: statusIsland
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.preferredHeight: statusCol.implicitHeight + (Config.barIslands ? 12 : 0)
                    radius: Config.barIslands ? 6 : 0
                    color: Config.barIslands ? Theme.surface : "transparent"

                    ColumnLayout {
                        id: statusCol
                        anchors.centerIn: parent
                        spacing: Config.barIslands ? 0 : 4

                        BarVolume { visible: Config.enableVolume }
                        BarMicrophone { visible: Config.enableMicrophone }
                        BarBrightness { visible: Config.enableBrightness }
                        BarEthernet { id: barEth; visible: Config.enableEthernet && (!Config.hideDisconnectedEthernet || barEth.up) }
                        BarWireless { id: barWifi; visible: Config.enableWireless && (!Config.hideDisconnectedWireless || barWifi.up) }
                        BarWireguard { id: barWg; visible: Config.enableWireguard && (!Config.hideDisconnectedWireguard || barWg.anyUp) }
                        BarBluetooth { id: barBt; visible: Config.enableBluetooth && (!Config.hideDisconnectedBluetooth || barBt.powered) }
                        BarBattery { visible: Config.enableBattery }
                        BarNotifications { visible: Config.enableNotifications }
                        BarPower { visible: Config.enablePower }
                    }
                }
            }
        }
    }
}
