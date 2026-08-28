import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableBluetoothPanel ? Quickshell.screens : []
        PanelWindow {
            id: btPanelWindow
            property var modelData
            screen: modelData
            visible: root.btPanelVisible
            WlrLayershell.namespace: "qs-btpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property var pairedDevices: []
            property var nearbyDevices: []
            property bool powered: false
            property var connectedDevices: pairedDevices.filter(function(d) { return d.connected })
            property var disconnectedDevices: pairedDevices.filter(function(d) { return !d.connected })

            onVisibleChanged: {
                if (visible) {
                    btRefresh.running = true
                    btScanProc.running = true
                    btScanRefreshTimer.restart()
                } else {
                    btScanProc.running = false
                    btScanRefreshTimer.stop()
                }
            }

            Process {
                id: btRefresh
                command: ["sh", "-c",
                    "echo '---POWER---';"
                    + "bluetoothctl show 2>/dev/null | grep 'Powered:';"
                    + "echo '---PAIRED---';"
                    + "connected=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}');"
                    + "paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}');"
                    + "for mac in $paired; do"
                    + "  info=$(bluetoothctl info \"$mac\" 2>/dev/null);"
                    + "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2}');"
                    + "  [ -z \"$name\" ] && continue;"
                    + "  icon=$(echo \"$info\" | awk -F': ' '/^\\tIcon:/{print $2}');"
                    + "  bat=$(echo \"$info\" | awk -F'[(): ]' '/Battery Percentage:/{for(i=1;i<=NF;i++) if($i~/^[0-9]+$/) print $i}');"
                    + "  conn=0; echo \"$connected\" | grep -qx \"$mac\" && conn=1;"
                    + "  echo \"PAIRED|${mac}|${name}|${icon}|${conn}|${bat}\";"
                    + "done;"
                    + "echo '---NEARBY---';"
                    + "for mac in $(bluetoothctl devices 2>/dev/null | awk '{print $2}'); do"
                    + "  echo \"$paired\" | grep -qx \"$mac\" && continue;"
                    + "  info=$(bluetoothctl info \"$mac\" 2>/dev/null);"
                    + "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2}');"
                    + "  [ -z \"$name\" ] && continue;"
                    + "  echo \"$name\" | grep -qE '^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$' && continue;"
                    + "  icon=$(echo \"$info\" | awk -F': ' '/^\\tIcon:/{print $2}');"
                    + "  echo \"NEARBY|${mac}|${name}|${icon}\";"
                    + "done"]
                stdout: SplitParser {
                    property string section: ""
                    property var pairedList: []
                    property var nearbyList: []
                    onRead: data => {
                        var s = data.trim()
                        if (s === "---POWER---") { section = "power"; return }
                        if (s === "---PAIRED---") { section = "paired"; pairedList = []; return }
                        if (s === "---NEARBY---") { section = "nearby"; nearbyList = []; return }
                        if (section === "power") {
                            if (s.includes("Powered: yes")) btPanelWindow.powered = true
                            else if (s.includes("Powered: no")) btPanelWindow.powered = false
                        }
                        if (section === "paired" && s.startsWith("PAIRED|")) {
                            var parts = s.substring(7).split("|")
                            pairedList.push({
                                mac: parts[0] || "",
                                name: parts[1] || "Unknown",
                                icon: parts[2] || "",
                                connected: parts[3] === "1",
                                battery: parts[4] ? parseInt(parts[4]) : -1
                            })
                        }
                        if (section === "nearby" && s.startsWith("NEARBY|")) {
                            var parts = s.substring(7).split("|")
                            nearbyList.push({
                                mac: parts[0] || "",
                                name: parts[1] || "Unknown",
                                icon: parts[2] || ""
                            })
                        }
                    }
                }
                onExited: {
                    var paired = stdout.pairedList ?? []
                    paired.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    btPanelWindow.pairedDevices = paired
                    var nearby = stdout.nearbyList ?? []
                    nearby.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    btPanelWindow.nearbyDevices = nearby
                    stdout.section = ""
                    stdout.pairedList = []
                    stdout.nearbyList = []
                }
            }

            // Long-running scan — piped stdin keeps bluetoothctl (and its D-Bus
            // connection) alive; killing the process auto-stops discovery.
            Process {
                id: btScanProc
                command: ["sh", "-c", "{ echo 'scan on'; sleep infinity; } | bluetoothctl"]
            }

            // Periodically refresh while scanning to pick up new devices
            Timer {
                id: btScanRefreshTimer
                interval: 3000
                repeat: true
                onTriggered: {
                    btRefresh.running = false
                    btRefresh.running = true
                }
            }

            Process {
                id: btConnectProc
                property string action: ""
                property string mac: ""
                command: ["bluetoothctl", action, mac]
                onExited: btDelayedRefresh.restart()
            }

            // Pair then connect a nearby (non-paired) device
            Process {
                id: btPairConnectProc
                property string mac: ""
                command: ["sh", "-c",
                    "bluetoothctl pair '" + mac + "' && bluetoothctl connect '" + mac + "'"]
                onExited: btDelayedRefresh.restart()
            }

            Process {
                id: btPowerProc
                property string state: ""
                command: ["bluetoothctl", "power", state]
                onExited: {
                    btDelayedRefresh.restart()
                    if (state === "on") btScanRestart.restart()
                }
            }

            // Restart scan after power-on (old scan process dies when adapter powers off)
            Timer {
                id: btScanRestart
                interval: 1500
                onTriggered: {
                    btScanProc.running = false
                    btScanProc.running = true
                }
            }

            Timer {
                id: btDelayedRefresh
                interval: 1000
                onTriggered: {
                    btRefresh.running = false
                    btRefresh.running = true
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.btPanelVisible = false
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: Math.max(Config.barGap, Math.min(
                    parent.height - height - Config.barGap,
                    root.btPanelY - 18
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

                    // Header
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Bluetooth"
                            font { family: Config.fontFamily; pixelSize: 14; bold: true }
                            color: Theme.text
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: powerRow.implicitWidth + 12
                            height: 22; radius: 6
                            color: powerMA.containsMouse ? Theme.highlightMed : Theme.highlightLow
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Row {
                                id: powerRow
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: btPanelWindow.powered ? Theme.bluetoothColor : Theme.muted
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: btPanelWindow.powered ? "On" : "Off"
                                    font { family: Config.fontFamily; pixelSize: 11 }
                                    color: btPanelWindow.powered ? Theme.bluetoothColor : Theme.muted
                                }
                            }

                            MouseArea {
                                id: powerMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    btPowerProc.state = btPanelWindow.powered ? "off" : "on"
                                    btPowerProc.running = true
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.highlightMed }

                    // Empty state
                    Text {
                        visible: !btPanelWindow.powered
                        text: "Bluetooth is off"
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.muted
                    }

                    // Connected devices
                    Repeater {
                        model: btPanelWindow.connectedDevices
                        delegate: BtDeviceDelegate {
                            required property var modelData
                            device: modelData
                            Layout.fillWidth: true
                            onToggle: {
                                btConnectProc.action = "disconnect"
                                btConnectProc.mac = modelData.mac
                                btConnectProc.running = true
                            }
                        }
                    }

                    // Disconnected (paired) devices
                    Repeater {
                        model: btPanelWindow.disconnectedDevices
                        delegate: BtDeviceDelegate {
                            required property var modelData
                            device: modelData
                            Layout.fillWidth: true
                            onToggle: {
                                btConnectProc.action = "connect"
                                btConnectProc.mac = modelData.mac
                                btConnectProc.running = true
                            }
                        }
                    }

                    // Nearby (discovered, not paired) devices
                    Repeater {
                        model: btPanelWindow.nearbyDevices
                        delegate: BtNearbyDelegate {
                            required property var modelData
                            device: modelData
                            Layout.fillWidth: true
                            onConnect: {
                                btPairConnectProc.mac = modelData.mac
                                btPairConnectProc.running = true
                            }
                        }
                    }

                    Text {
                        visible: btPanelWindow.powered && btPanelWindow.pairedDevices.length === 0 && btPanelWindow.nearbyDevices.length === 0
                        text: "No devices found"
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.muted
                    }
                }
            }
        }
    }

    component BtDeviceDelegate: Rectangle {
        id: del
        property var device
        signal toggle()

        implicitHeight: 36
        radius: 8
        color: device.connected ? Theme.overlay
            : ma.containsMouse ? Theme.highlightMed : "transparent"
        border.color: device.connected ? Theme.bluetoothColor : "transparent"
        border.width: device.connected ? 1 : 0
        Behavior on color { ColorAnimation { duration: 80 } }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8

            // Device type icon
            Item {
                id: iconWrap
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: {
                        var ic = del.device.icon
                        if (ic.includes("keyboard")) return "󰌌"
                        if (ic.includes("mouse")) return "󰍽"
                        if (ic.includes("audio") || ic.includes("headset") || ic.includes("headphone")) return "󰋋"
                        if (ic.includes("phone")) return "󰏲"
                        return "󰂯"
                    }
                    font { family: Config.fontFamily; pixelSize: 14 }
                    color: del.device.connected ? Theme.bluetoothColor : Theme.muted
                }
            }

            // Name
            Text {
                anchors.left: iconWrap.right; anchors.leftMargin: 8
                anchors.right: batText.visible ? batText.left : dot.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: del.device.name
                font { family: Config.fontFamily; pixelSize: 12 }
                color: del.device.connected || ma.containsMouse ? Theme.text : Theme.subtle
                Behavior on color { ColorAnimation { duration: 80 } }
                elide: Text.ElideRight
            }

            // Battery
            Text {
                id: batText
                visible: del.device.battery >= 0
                anchors.right: dot.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: del.device.battery + "%"
                font { family: Config.fontFamily; pixelSize: 11 }
                color: del.device.battery <= 20 ? Theme.love
                    : del.device.battery <= 40 ? Theme.gold
                    : Theme.subtle
            }

            // Status dot
            Rectangle {
                id: dot
                width: 8; height: 8; radius: 4
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: del.device.connected ? Theme.bluetoothColor : Theme.muted
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: del.toggle()
        }
    }

    component BtNearbyDelegate: Rectangle {
        id: ndel
        property var device
        signal connect()

        implicitHeight: 36
        radius: 8
        color: nma.containsMouse ? Theme.highlightMed : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8

            Item {
                id: nIconWrap
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: {
                        var ic = ndel.device.icon
                        if (ic.includes("keyboard")) return "󰌌"
                        if (ic.includes("mouse")) return "󰍽"
                        if (ic.includes("audio") || ic.includes("headset") || ic.includes("headphone")) return "󰋋"
                        if (ic.includes("phone")) return "󰏲"
                        return "󰂯"
                    }
                    font { family: Config.fontFamily; pixelSize: 14 }
                    color: nma.containsMouse ? Theme.text : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
            }

            Text {
                anchors.left: nIconWrap.right; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: ndel.device.name
                font { family: Config.fontFamily; pixelSize: 12 }
                color: nma.containsMouse ? Theme.text : Theme.subtle
                Behavior on color { ColorAnimation { duration: 80 } }
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: nma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: ndel.connect()
        }
    }
}
