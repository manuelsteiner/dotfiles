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
            color: "transparent"

            // Idle dim (rule 18): the bar dims rather than hides. Popouts and
            // OSDs always open at full opacity — this only affects the island
            // column below (PanelWindow itself has no `opacity` property).
            property bool idle: false

            Timer {
                id: idleTimer
                interval: Config.barIdleTimeout
                running: Config.barIdleDim
                onTriggered: barWindow.idle = true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onPositionChanged: mouse => { barWindow.idle = false; idleTimer.restart(); mouse.accepted = false }
                onPressed: mouse => { barWindow.idle = false; idleTimer.restart(); mouse.accepted = false }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Config.gap
                anchors.bottomMargin: Config.gap
                anchors.leftMargin: Config.barIslands ? Config.gap : 0
                anchors.rightMargin: 0
                spacing: Config.barIslands ? Config.gap : 4

                opacity: Config.barIdleDim && barWindow.idle ? Config.barIdleOpacity : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: barWindow.idle ? 400 : 120 }
                }

                // ── Clock island ──
                BarIsland {
                    visible: Config.enableClock
                    Layout.preferredHeight: clockItem.implicitHeight + (Config.barIslands ? 12 : 0)

                    BarClock {
                        id: clockItem
                        anchors.centerIn: parent
                        width: parent.width
                        screen: barWindow.screen
                    }
                }

                BarSeparator { visible: !Config.barIslands && Config.enableClock && Config.enableWorkspaces }

                // ── Workspaces island ──
                BarIsland {
                    visible: Config.enableWorkspaces
                    Layout.preferredHeight: wsItem.implicitHeight + (Config.barIslands ? 12 : 0)

                    BarWorkspaces {
                        id: wsItem
                        anchors.centerIn: parent
                    }
                }

                BarSeparator { visible: !Config.barIslands && Config.enableWorkspaces }

                Item { Layout.fillHeight: true }

                BarSeparator { visible: !Config.barIslands }

                // ── System tray island ──
                BarIsland {
                    visible: Config.enableSystemTray && barTray.height > 0
                    Layout.preferredHeight: barTray.implicitHeight + (Config.barIslands ? 12 : 0)

                    BarSystemTray {
                        id: barTray
                        anchors.centerIn: parent
                        screen: barWindow.screen
                    }
                }

                BarSeparator { visible: !Config.barIslands && Config.enableSystemTray && barTray.height > 0 }

                // ── Status island ──
                BarIsland {
                    id: statusIsland
                    Layout.preferredHeight: statusCol.implicitHeight + (Config.barIslands ? 12 : 0)

                    ColumnLayout {
                        id: statusCol
                        anchors.centerIn: parent
                        // 2px even in island mode: two adjacent cells with a
                        // 1px accent/urgent border would otherwise touch and
                        // merge into what reads as a single double-line.
                        spacing: Config.barIslands ? 2 : 4

                        BarVolume { visible: Config.enableVolume; screen: barWindow.screen }
                        BarMicrophone { visible: Config.enableMicrophone; screen: barWindow.screen }
                        BarBrightness { visible: Config.enableBrightness; screen: barWindow.screen }
                        BarEthernet { id: barEth; visible: Config.enableEthernet && (!Config.hideDisconnectedEthernet || barEth.up); screen: barWindow.screen }
                        BarWireless { id: barWifi; visible: Config.enableWireless && (!Config.hideDisconnectedWireless || barWifi.up); screen: barWindow.screen }
                        BarWireguard { id: barWg; visible: Config.enableWireguard && (!Config.hideDisconnectedWireguard || barWg.anyUp); screen: barWindow.screen }
                        BarBluetooth { id: barBt; visible: Config.enableBluetooth && (!Config.hideDisconnectedBluetooth || barBt.powered); screen: barWindow.screen }
                        BarBattery { visible: Config.enableBattery; screen: barWindow.screen }
                        BarNotifications { visible: Config.enableNotifications; screen: barWindow.screen }
                        BarPower { visible: Config.enablePower; screen: barWindow.screen }
                    }
                }
            }
        }
    }
}
