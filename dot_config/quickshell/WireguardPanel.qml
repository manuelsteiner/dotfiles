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
            visible: root.wgPanelVisible && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-wgpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property var tunnels: []
            property var upTunnels: tunnels.filter(function(t) { return t.up })
            property var downTunnels: tunnels.filter(function(t) { return !t.up })

            // D-9 keyboard traversal. Tunnels are plain data objects replaced
            // wholesale on refresh, so focus is a position in the up→down
            // order, not object identity.
            property int focusedIndex: -1
            readonly property int totalTunnelCount: upTunnels.length + downTunnels.length

            function moveFocus(delta) {
                if (totalTunnelCount === 0) return
                focusedIndex = Math.max(0, Math.min(totalTunnelCount - 1, focusedIndex + delta))
            }
            function activateFocused() {
                var upLen = upTunnels.length
                var idx = focusedIndex
                if (idx < 0) return
                if (idx < upLen) {
                    wgToggleProc.action = "down"
                    wgToggleProc.iface = upTunnels[idx].iface
                    wgToggleProc.running = true
                } else {
                    var t = downTunnels[idx - upLen]
                    if (t) {
                        wgToggleProc.action = "up"
                        wgToggleProc.iface = t.iface
                        wgToggleProc.running = true
                    }
                }
            }

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
                if (visible) {
                    wgRefresh.running = true
                    focusedIndex = totalTunnelCount > 0 ? 0 : -1
                }
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
                focus: true
                Keys.onEscapePressed: root.wgPanelVisible = false
                Keys.onUpPressed: wgPanelWindow.moveFocus(-1)
                Keys.onDownPressed: wgPanelWindow.moveFocus(1)
                Keys.onReturnPressed: wgPanelWindow.activateFocused()
                Keys.onEnterPressed: wgPanelWindow.activateFocused()
            }

            PopoutFrame {
                anchors.left: parent.left
                y: Math.max(Config.gap, Math.min(
                    parent.height - height - Config.gap,
                    root.wgPanelY - 18
                ))
                width: 280
                height: panelCol.implicitHeight + 24

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: panelCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "WireGuard"
                        font { family: Config.fontFamily; pixelSize: 13; bold: true }
                        color: Theme.text
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

                    // Empty state — no power/enable control exists for this panel, so a
                    // minimal hint is kept rather than collapsing to just the header (D-7).
                    Text {
                        visible: wgPanelWindow.tunnels.length === 0
                        text: "No tunnels configured"
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.subtle
                    }

                    // Connected tunnels — integer-count model with self-index
                    // lookup, not the array itself: `tunnels` is rebuilt
                    // wholesale on every ~3s poll, and Qt 6.11's Repeater can
                    // segfault in QQuickRepeater::regenerate() when a plain
                    // JS-array model gets reassigned that often (this is what
                    // crashed NotificationPanel.qml before it got the same
                    // treatment).
                    Repeater {
                        model: wgPanelWindow.upTunnels.length
                        delegate: WgTunnelDelegate {
                            id: upDel
                            required property int index
                            readonly property var modelData: wgPanelWindow.upTunnels[index]
                            tunnel: upDel.modelData
                            isFocused: index === wgPanelWindow.focusedIndex
                            Layout.fillWidth: true
                            onToggle: {
                                wgToggleProc.action = "down"
                                wgToggleProc.iface = upDel.modelData.iface
                                wgToggleProc.running = true
                            }
                            onHovered: wgPanelWindow.focusedIndex = index
                        }
                    }

                    // Disconnected tunnels
                    Repeater {
                        model: wgPanelWindow.downTunnels.length
                        delegate: WgTunnelDelegate {
                            id: downDel
                            required property int index
                            readonly property var modelData: wgPanelWindow.downTunnels[index]
                            readonly property int globalIndex: wgPanelWindow.upTunnels.length + index
                            tunnel: downDel.modelData
                            isFocused: globalIndex === wgPanelWindow.focusedIndex
                            Layout.fillWidth: true
                            onToggle: {
                                wgToggleProc.action = "up"
                                wgToggleProc.iface = downDel.modelData.iface
                                wgToggleProc.running = true
                            }
                            onHovered: wgPanelWindow.focusedIndex = globalIndex
                        }
                    }
                }
            }
        }
    }

    component WgTunnelDelegate: Rectangle {
        id: del
        property var tunnel
        property bool isFocused: false
        signal toggle()
        signal hovered()

        implicitHeight: (tunnel.up && tunnel.ip) ? 44 : 36
        radius: Config.radiusCell
        color: tunnel.up
            ? (isFocused ? Theme.press : Theme.elev2)
            : (isFocused ? Theme.hover : "transparent")
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
                color: del.tunnel.up || del.isFocused ? Theme.text : Theme.subtle
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
            onEntered: del.hovered()
            onClicked: del.toggle()
        }
    }
}
