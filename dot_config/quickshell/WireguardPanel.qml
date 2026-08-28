import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableWireguardPanel ? Quickshell.screens : []
        PanelWindow {
            id: wgPanelWindow
            property var modelData
            screen: modelData
            visible: root.wgPanelVisible
            WlrLayershell.namespace: "qs-wgpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property var tunnels: []
            property var upTunnels: tunnels.filter(function(t) { return t.up })
            property var downTunnels: tunnels.filter(function(t) { return !t.up })

            function buildRefreshCmd() {
                var parts = []
                var ifaces = Config.wireguardInterfaces
                for (var i = 0; i < ifaces.length; i++) {
                    parts.push(
                        "echo 'IF:" + ifaces[i] + "';"
                        + "cat /sys/class/net/" + ifaces[i] + "/operstate 2>/dev/null || echo down;"
                        + "ip -4 addr show " + ifaces[i] + " 2>/dev/null"
                        + " | awk '/inet /{split($2,a,\"/\"); print \"IP:\"a[1]}'"
                    )
                }
                return parts.join(";")
            }

            onVisibleChanged: {
                if (visible) wgRefresh.running = true
            }

            Process {
                id: wgRefresh
                command: ["sh", "-c", wgPanelWindow.buildRefreshCmd()]
                stdout: SplitParser {
                    property string currentIface: ""
                    property bool currentUp: false
                    property string currentIp: ""
                    property var results: []

                    onRead: data => {
                        var s = data.trim()
                        if (s.startsWith("IF:")) {
                            if (currentIface !== "") {
                                results.push({ iface: currentIface, up: currentUp, ip: currentIp })
                            }
                            currentIface = s.substring(3)
                            currentUp = false
                            currentIp = ""
                            return
                        }
                        if (s === "up" || s === "unknown") currentUp = true
                        if (s === "down") currentUp = false
                        if (s.startsWith("IP:")) currentIp = s.substring(3).trim()
                    }
                }
                onExited: {
                    var r = stdout.results
                    if (stdout.currentIface !== "") {
                        r.push({ iface: stdout.currentIface, up: stdout.currentUp, ip: stdout.currentIp })
                    }
                    r.sort(function(a, b) { return a.iface.localeCompare(b.iface) })
                    wgPanelWindow.tunnels = r
                    stdout.results = []
                    stdout.currentIface = ""
                    stdout.currentUp = false
                    stdout.currentIp = ""
                }
            }

            Process {
                id: wgToggleProc
                property string action: ""
                property string iface: ""
                command: ["pkexec", "networkctl", action === "up" ? "up" : "down", iface]
                onExited: wgRefresh.running = true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.wgPanelVisible = false
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: Math.max(Config.barGap, Math.min(
                    parent.height - height - Config.barGap,
                    root.wgPanelY - 18
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
                        text: "WireGuard"
                        font { family: Config.fontFamily; pixelSize: 14; bold: true }
                        color: Theme.text
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.highlightMed }

                    // Empty state
                    Text {
                        visible: wgPanelWindow.tunnels.length === 0
                        text: "No tunnels configured"
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.muted
                    }

                    // Connected tunnels
                    Repeater {
                        model: wgPanelWindow.upTunnels
                        delegate: WgTunnelDelegate {
                            required property var modelData
                            tunnel: modelData
                            Layout.fillWidth: true
                            onToggle: {
                                wgToggleProc.action = "down"
                                wgToggleProc.iface = modelData.iface
                                wgToggleProc.running = true
                            }
                        }
                    }

                    // Disconnected tunnels
                    Repeater {
                        model: wgPanelWindow.downTunnels
                        delegate: WgTunnelDelegate {
                            required property var modelData
                            tunnel: modelData
                            Layout.fillWidth: true
                            onToggle: {
                                wgToggleProc.action = "up"
                                wgToggleProc.iface = modelData.iface
                                wgToggleProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    component WgTunnelDelegate: Rectangle {
        id: del
        property var tunnel
        signal toggle()

        implicitHeight: (tunnel.up && tunnel.ip) ? 44 : 36
        radius: 8
        color: tunnel.up ? Theme.overlay
            : ma.containsMouse ? Theme.highlightMed : "transparent"
        border.color: tunnel.up ? Theme.wireguardColor : "transparent"
        border.width: tunnel.up ? 1 : 0
        Behavior on color { ColorAnimation { duration: 80 } }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8

            // VPN icon
            Item {
                id: iconWrap
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: "󰴳"
                    font { family: Config.fontFamily; pixelSize: 14 }
                    color: del.tunnel.up ? Theme.wireguardColor : Theme.muted
                }
            }

            // Interface name + IP beneath
            Text {
                anchors.left: iconWrap.right; anchors.leftMargin: 8
                anchors.right: dot.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: del.tunnel.iface
                    + (del.tunnel.up && del.tunnel.ip ? "\n" + del.tunnel.ip : "")
                lineHeight: del.tunnel.up && del.tunnel.ip ? 0.9 : 1.0
                font { family: Config.fontFamily
                       pixelSize: del.tunnel.up && del.tunnel.ip ? 11 : 12
                       bold: del.tunnel.up }
                color: del.tunnel.up || ma.containsMouse ? Theme.text : Theme.subtle
                Behavior on color { ColorAnimation { duration: 80 } }
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            // Status dot
            Rectangle {
                id: dot
                width: 8; height: 8; radius: 4
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: del.tunnel.up ? Theme.wireguardColor : Theme.muted
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: del.toggle()
        }
    }
}
