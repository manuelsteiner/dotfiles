import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableWirelessPanel ? Quickshell.screens : []
        PanelWindow {
            id: wifiPanelWindow
            property var modelData
            screen: modelData
            visible: root.wifiPanelVisible
            WlrLayershell.namespace: "qs-wifipanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property var networks: []
            property var knownSsids: []
            property string connectedSsid: ""
            property string connectedIp: ""
            property int connectedSignal: 0
            property bool scanning: false
            property bool powered: false

            // Password input state — tracks which SSID needs a password
            property string pendingSsid: ""

            property var connectedNetworks: networks.filter(function(n) { return n.connected })
            property var availableNetworks: networks.filter(function(n) { return !n.connected })

            onVisibleChanged: {
                if (visible) {
                    wifiRefresh.running = true
                    wifiScan.running = true
                } else {
                    wifiPanelWindow.pendingSsid = ""
                    wifiScanRefresh.stop()
                }
            }

            Process {
                id: wifiRefresh
                property string iface: Config.wirelessInterface
                command: ["sh", "-c",
                    "echo '---PWR---';"
                    + "rfkill -n -o SOFT list wifi 2>/dev/null | head -1;"
                    + "echo '---CONN---';"
                    + "iwctl station " + iface + " show 2>/dev/null | awk '"
                    + "  /Connected network/{sub(/.*Connected network */, \"\"); print \"SSID:\"$0}"
                    + "  /IPv4 address/{sub(/.*IPv4 address */, \"\"); print \"IP:\"$0}"
                    + "  /RSSI/{sub(/.*RSSI */, \"\"); gsub(/ /,\"\",$0); print \"RSSI:\"$0}"
                    + "';"
                    + "echo '---NETS---';"
                    + "iwctl station " + iface + " get-networks 2>/dev/null"
                    + " | sed 's/\\x1b\\[[0-9;]*[mGK]//g; s/\\r//g'"
                    + " | awk '"
                    + "  BEGIN{hdr=0}"
                    + "  /^-+$/{hdr++;next}"
                    + "  hdr<2{next}"
                    + "  /^[[:space:]]*$/{next}"
                    + "  {"
                    + "    conn=(index($0,\">\")>0 && index($0,\">\")<6)?1:0;"
                    + "    line=$0;"
                    + "    sig=0;"
                    + "    for(i=length(line);i>0;i--){"
                    + "      c=substr(line,i,1);"
                    + "      if(c==\"*\")sig++;"
                    + "      else if(c!=\" \")break"
                    + "    }"
                    + "    gsub(/[* ]+$/,\"\",line);"
                    + "    gsub(/^[> ]+/,\"\",line);"
                    + "    n=split(line,a);"
                    + "    sec=a[n];"
                    + "    name=\"\";"
                    + "    for(i=1;i<n;i++){if(i>1)name=name\" \";name=name a[i]}"
                    + "    if(name!=\"\")print \"NET|\"conn\"|\"sig\"|\"sec\"|\"name"
                    + "  }';"
                    + "echo '---KNOWN---';"
                    + "iwctl known-networks list 2>/dev/null"
                    + " | sed 's/\\x1b\\[[0-9;]*[mGK]//g; s/\\r//g'"
                    + " | awk '"
                    + "  BEGIN{hdr=0;col2=0}"
                    + "  /^-+$/{hdr++;next}"
                    + "  hdr==1 && /Security/{col2=index($0,\"Security\");next}"
                    + "  hdr<2{next}"
                    + "  /^[[:space:]]*$/{next}"
                    + "  col2>0{"
                    + "    name=substr($0,1,col2-1);"
                    + "    gsub(/^[[:space:]]+|[[:space:]]+$/,\"\",name);"
                    + "    if(name!=\"\")print \"KN|\"name"
                    + "  }'"
                ]
                stdout: SplitParser {
                    property string section: ""
                    property bool cPowered: false
                    property string cSsid: ""
                    property string cIp: ""
                    property int cRssi: 0
                    property var netList: []
                    property var knownList: []

                    onRead: data => {
                        var s = data.trim()
                        if (s === "---PWR---") { section = "pwr"; return }
                        if (s === "---CONN---") { section = "conn"; return }
                        if (s === "---NETS---") { section = "nets"; netList = []; return }
                        if (s === "---KNOWN---") { section = "known"; knownList = []; return }

                        if (section === "pwr") {
                            if (s === "unblocked") cPowered = true
                            else if (s === "blocked") cPowered = false
                        }
                        if (section === "conn") {
                            if (s.startsWith("SSID:")) cSsid = s.substring(5).trim()
                            if (s.startsWith("IP:")) cIp = s.substring(3).trim()
                            if (s.startsWith("RSSI:")) {
                                var dbm = parseInt(s.substring(5))
                                if (!isNaN(dbm))
                                    cRssi = Math.min(100, Math.max(0, 2 * (dbm + 100)))
                            }
                        }
                        if (section === "nets" && s.startsWith("NET|")) {
                            var parts = s.substring(4).split("|")
                            netList.push({
                                connected: parts[0] === "1",
                                signal: parseInt(parts[1]) || 0,
                                security: parts[2] || "open",
                                ssid: parts[3] || ""
                            })
                        }
                        if (section === "known" && s.startsWith("KN|")) {
                            knownList.push(s.substring(3))
                        }
                    }
                }
                onRunningChanged: {
                    if (running) wifiPanelWindow.scanning = true
                }
                onExited: {
                    wifiPanelWindow.powered = stdout.cPowered
                    wifiPanelWindow.connectedSsid = stdout.cSsid
                    wifiPanelWindow.connectedIp = stdout.cIp
                    wifiPanelWindow.connectedSignal = stdout.cRssi
                    wifiPanelWindow.networks = stdout.netList ?? []
                    wifiPanelWindow.knownSsids = stdout.knownList ?? []
                    wifiPanelWindow.scanning = false
                    stdout.section = ""
                    stdout.cPowered = false
                    stdout.cSsid = ""
                    stdout.cIp = ""
                    stdout.cRssi = 0
                    stdout.netList = []
                    stdout.knownList = []
                }
            }

            Process {
                id: wifiScan
                command: ["iwctl", "station", Config.wirelessInterface, "scan"]
                onExited: wifiScanRefresh.restart()
            }

            Timer {
                id: wifiScanRefresh
                interval: 1500
                onTriggered: {
                    wifiRefresh.running = false
                    wifiRefresh.running = true
                }
            }

            Process {
                id: wifiConnectProc
                property string ssid: ""
                property string passphrase: ""
                command: passphrase !== ""
                    ? ["iwctl", "--passphrase=" + passphrase,
                       "station", Config.wirelessInterface, "connect", ssid]
                    : ["iwctl", "station", Config.wirelessInterface, "connect", ssid]
                onExited: {
                    wifiPanelWindow.pendingSsid = ""
                    wifiDelayedRefresh.restart()
                }
            }

            Process {
                id: wifiDisconnectProc
                command: ["iwctl", "station", Config.wirelessInterface, "disconnect"]
                onExited: wifiDelayedRefresh.restart()
            }

            Process {
                id: wifiPowerProc
                property string action: ""
                command: ["rfkill", action, "wifi"]
                onExited: wifiDelayedRefresh.restart()
            }

            Timer {
                id: wifiDelayedRefresh
                interval: 1000
                onTriggered: {
                    wifiRefresh.running = false
                    wifiRefresh.running = true
                }
            }

            function connectNetwork(ssid, security) {
                if (security === "open" || knownSsids.indexOf(ssid) >= 0) {
                    // Open network or iwd has cached credentials — connect directly
                    wifiConnectProc.ssid = ssid
                    wifiConnectProc.passphrase = ""
                    wifiConnectProc.running = true
                } else {
                    // Unknown secured network — prompt for password
                    wifiPanelWindow.pendingSsid = ssid
                }
            }

            function submitPassword(ssid, password) {
                wifiConnectProc.ssid = ssid
                wifiConnectProc.passphrase = password
                wifiConnectProc.running = true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.wifiPanelVisible = false
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: Math.max(Config.barGap, Math.min(
                    parent.height - height - Config.barGap,
                    root.wifiPanelY - 18
                ))
                width: 280
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
                            text: "Wi-Fi"
                            font { family: Config.fontFamily; pixelSize: 14; bold: true }
                            color: Theme.text
                        }

                        // Power toggle
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
                                    color: wifiPanelWindow.powered ? Theme.wirelessColor : Theme.muted
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: wifiPanelWindow.powered ? "On" : "Off"
                                    font { family: Config.fontFamily; pixelSize: 11 }
                                    color: wifiPanelWindow.powered ? Theme.wirelessColor : Theme.muted
                                }
                            }

                            MouseArea {
                                id: powerMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wifiPowerProc.action = wifiPanelWindow.powered ? "block" : "unblock"
                                    wifiPowerProc.running = true
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.highlightMed }

                    // Empty / off state
                    Text {
                        visible: !wifiPanelWindow.powered
                        text: "Wi-Fi is off"
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.muted
                    }

                    Text {
                        visible: wifiPanelWindow.powered && wifiPanelWindow.networks.length === 0 && !wifiPanelWindow.scanning
                        text: "No networks found"
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.muted
                    }

                    Text {
                        visible: wifiPanelWindow.powered && wifiPanelWindow.networks.length === 0 && wifiPanelWindow.scanning
                        text: "Scanning..."
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.muted
                    }

                    // Connected networks
                    Repeater {
                        model: wifiPanelWindow.connectedNetworks
                        delegate: WifiNetworkDelegate {
                            required property var modelData
                            network: modelData
                            connectedIp: wifiPanelWindow.connectedIp
                            connectedSignalPct: wifiPanelWindow.connectedSignal
                            pendingSsid: wifiPanelWindow.pendingSsid
                            Layout.fillWidth: true
                            onToggle: wifiDisconnectProc.running = true
                            onSubmitPassword: pass => wifiPanelWindow.submitPassword(modelData.ssid, pass)
                        }
                    }

                    // Available networks
                    Repeater {
                        model: wifiPanelWindow.availableNetworks
                        delegate: WifiNetworkDelegate {
                            required property var modelData
                            network: modelData
                            pendingSsid: wifiPanelWindow.pendingSsid
                            Layout.fillWidth: true
                            onToggle: wifiPanelWindow.connectNetwork(modelData.ssid, modelData.security)
                            onSubmitPassword: pass => wifiPanelWindow.submitPassword(modelData.ssid, pass)
                        }
                    }
                }
            }
        }
    }

    component WifiNetworkDelegate: Column {
        id: del
        property var network
        property string connectedIp: ""
        property int connectedSignalPct: 0
        property string pendingSsid: ""
        signal toggle()
        signal submitPassword(string password)

        property bool showPassword: pendingSsid !== "" && pendingSsid === network.ssid

        spacing: 4
        Layout.fillWidth: true

        Rectangle {
            width: del.width
            height: 36
            radius: 8
            color: network.connected ? Theme.overlay
                : ma.containsMouse ? Theme.highlightMed : "transparent"
            border.color: network.connected ? Theme.wirelessColor : "transparent"
            border.width: network.connected ? 1 : 0
            Behavior on color { ColorAnimation { duration: 80 } }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8

                // WiFi signal icon
                Item {
                    id: iconWrap
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: {
                            var s = del.network.signal
                            if (s >= 4) return "󰤨"
                            if (s >= 3) return "󰤥"
                            if (s >= 2) return "󰤢"
                            if (s >= 1) return "󰤟"
                            return "󰤯"
                        }
                        font { family: Config.fontFamily; pixelSize: 14 }
                        color: del.network.connected ? Theme.wirelessColor : Theme.muted
                    }
                }

                // SSID
                Text {
                    anchors.left: iconWrap.right; anchors.leftMargin: 8
                    anchors.right: secIcon.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: del.network.ssid
                        + (del.network.connected && del.connectedIp ? "\n" + del.connectedIp : "")
                    lineHeight: del.network.connected && del.connectedIp ? 0.9 : 1.0
                    font { family: Config.fontFamily
                           pixelSize: del.network.connected && del.connectedIp ? 11 : 12
                           bold: del.network.connected }
                    color: del.network.connected || ma.containsMouse ? Theme.text : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 80 } }
                    elide: Text.ElideRight
                    maximumLineCount: 2
                }

                // Security icon
                Text {
                    id: secIcon
                    anchors.right: dot.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: del.network.security !== "open"
                    text: "󰌆"
                    font { family: Config.fontFamily; pixelSize: 11 }
                    color: Theme.subtle
                }

                // Status dot
                Rectangle {
                    id: dot
                    width: 8; height: 8; radius: 4
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: del.network.connected ? Theme.wirelessColor : Theme.muted
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                onClicked: del.toggle()
            }
        }

        // Inline password row — shown beneath this network when needed
        Rectangle {
            visible: del.showPassword
            width: del.width
            height: 36
            radius: 8
            color: Theme.highlightLow

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "󰌆"
                    font { family: Config.fontFamily; pixelSize: 14 }
                    color: Theme.muted
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: passInput
                        anchors.fill: parent
                        anchors.topMargin: 2; anchors.bottomMargin: 2
                        verticalAlignment: TextInput.AlignVCenter
                        font { family: Config.fontFamily; pixelSize: 12 }
                        color: Theme.text
                        echoMode: TextInput.Password
                        clip: true
                        onAccepted: del.submitPassword(text)

                        Text {
                            visible: !passInput.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Enter password"
                            font: passInput.font
                            color: Theme.muted
                        }
                    }
                }

                Text {
                    text: "󰌑"
                    font { family: Config.fontFamily; pixelSize: 16 }
                    color: passConnMA.containsMouse ? Theme.wirelessColor : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 80 } }

                    MouseArea {
                        id: passConnMA
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: del.submitPassword(passInput.text)
                    }
                }
            }

            onVisibleChanged: {
                if (visible) {
                    passInput.text = ""
                    passInput.forceActiveFocus()
                }
            }
        }
    }
}
