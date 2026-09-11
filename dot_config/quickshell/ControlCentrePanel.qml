import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// D2 control centre (v1, deliberately scoped down — see Config.useControlCentre's
// comment). Audio reads the global Pipewire singleton directly (no backend
// duplication). Network re-polls bluetoothctl/iwctl independently of
// BluetoothPanel/WirelessPanel (that state is private to those files) but only
// while this tab is actually open. Notifications is a flat (ungrouped) list of
// root.storedNotifications — the full grouped/expandable view stays in
// NotificationPanel.qml; this is a lighter summary. Media (MPRIS) and
// clipboard history are not implemented.
Scope {
    Variants {
        model: Config.useControlCentre ? Quickshell.screens : []
        PanelWindow {
            id: ccWindow
            property var modelData
            screen: modelData
            visible: root.controlCentreVisible && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-controlcentre"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property int activeTab: 0 // 0 notifications, 1 audio, 2 network, 3 themes
            property int networkSubTab: 0 // 0 ethernet, 1 wifi, 2 bluetooth

            readonly property int audioSourceCount: {
                var c = 0
                for (var i = 0; i < Pipewire.nodes.count; i++) {
                    var n = Pipewire.nodes.values[i]
                    if (!n.isSink && !n.isStream && n.audio) c++
                }
                return c
            }


            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.controlCentreVisible = false
                focus: true
                Keys.onEscapePressed: root.controlCentreVisible = false
            }

            // ── Network polling (only while the Network tab is actually open) ──
            property bool networkPollActive: ccWindow.visible && ccWindow.activeTab === 2

            // ── Ethernet ──
            property bool ethUp: false
            property string ethIpAddr: ""

            Process {
                id: ethRefreshProc
                command: ["sh", "-c",
                    "cat /sys/class/net/" + Config.ethernetInterface + "/operstate 2>/dev/null;"
                    + "echo '---IP---';"
                    + "ip -4 addr show " + Config.ethernetInterface + " 2>/dev/null"
                    + " | awk '/inet /{split($2,a,\"/\"); print \"IP:\"a[1]}'"]
                stdout: SplitParser {
                    property bool inIp: false
                    onRead: data => {
                        var s = data.trim()
                        if (s === "---IP---") { inIp = true; return }
                        if (!inIp) {
                            ccWindow.ethUp = s === "up"
                            if (!ccWindow.ethUp) ccWindow.ethIpAddr = ""
                        }
                        if (inIp && s.startsWith("IP:")) ccWindow.ethIpAddr = s.substring(3).trim()
                    }
                }
                onExited: stdout.inIp = false
            }

            Timer {
                interval: 3000; repeat: true; running: ccWindow.networkPollActive
                onTriggered: { ethRefreshProc.running = false; ethRefreshProc.running = true }
                triggeredOnStart: true
            }

            Process {
                id: ethToggleProc
                property string action: ""
                command: ["pkexec", "networkctl", action, Config.ethernetInterface]
                onExited: { ethRefreshProc.running = false; ethRefreshProc.running = true }
            }

            property bool wifiPowered: false
            property var wifiNetworks: []
            property var wifiKnownSsids: []
            property string wifiPendingSsid: ""
            readonly property var wifiConnected: wifiNetworks.filter(function(n) { return n.connected })
            readonly property var wifiKnownAvailable: wifiNetworks.filter(function(n) {
                return !n.connected && ccWindow.wifiKnownSsids.indexOf(n.ssid) >= 0
            }).sort(function(a, b) { return a.ssid.localeCompare(b.ssid) })
            readonly property var wifiUnknownAvailable: wifiNetworks.filter(function(n) {
                return !n.connected && ccWindow.wifiKnownSsids.indexOf(n.ssid) < 0
            }).sort(function(a, b) { return a.ssid.localeCompare(b.ssid) })
            readonly property var wifiAvailable: wifiKnownAvailable.concat(wifiUnknownAvailable)

            Process {
                id: wifiRefreshProc
                command: ["sh", "-c",
                    "rfkill -n -o SOFT list wifi 2>/dev/null | head -1;"
                    + "echo '---NETS---';"
                    + "iwctl station " + Config.wirelessInterface + " get-networks 2>/dev/null"
                    + " | sed 's/\\x1b\\[[0-9;]*[mGK]//g; s/\\r//g'"
                    + " | awk '"
                    + "  BEGIN{hdr=0}"
                    + "  /^-+$/{hdr++;next}"
                    + "  hdr<2{next}"
                    + "  /^[[:space:]]*$/{next}"
                    + "  {"
                    + "    conn=(index($0,\">\")>0 && index($0,\">\")<6)?1:0;"
                    + "    line=$0; gsub(/[* ]+$/,\"\",line); gsub(/^[> ]+/,\"\",line);"
                    + "    n=split(line,a); sec=a[n]; name=\"\";"
                    + "    for(i=1;i<n;i++){if(i>1)name=name\" \";name=name a[i]}"
                    + "    if(name!=\"\")print \"NET|\"conn\"|\"sec\"|\"name"
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
                    + "  col2>0{name=substr($0,1,col2-1); gsub(/^[[:space:]]+|[[:space:]]+$/,\"\",name); if(name!=\"\")print \"KN|\"name}'"
                ]
                stdout: SplitParser {
                    property bool inNets: false
                    property bool inKnown: false
                    property var netList: []
                    property var knownList: []
                    onRead: data => {
                        var s = data.trim()
                        if (s === "---NETS---") { inNets = true; inKnown = false; netList = []; return }
                        if (s === "---KNOWN---") { inNets = false; inKnown = true; knownList = []; return }
                        if (!inNets && !inKnown) {
                            ccWindow.wifiPowered = s === "unblocked"
                            return
                        }
                        if (inNets && s.startsWith("NET|")) {
                            var parts = s.substring(4).split("|")
                            netList.push({ connected: parts[0] === "1", security: parts[1] || "open", ssid: parts[2] || "" })
                        }
                        if (inKnown && s.startsWith("KN|")) knownList.push(s.substring(3))
                    }
                }
                onExited: {
                    ccWindow.wifiNetworks = stdout.netList ?? []
                    ccWindow.wifiKnownSsids = stdout.knownList ?? []
                    stdout.netList = []
                    stdout.knownList = []
                }
            }

            Timer {
                interval: 3000; repeat: true; running: ccWindow.networkPollActive
                onTriggered: { wifiRefreshProc.running = false; wifiRefreshProc.running = true }
                triggeredOnStart: true
            }

            Process {
                id: wifiConnectProc
                property string ssid: ""
                property string passphrase: ""
                command: passphrase !== ""
                    ? ["iwctl", "--passphrase=" + passphrase, "station", Config.wirelessInterface, "connect", ssid]
                    : ["iwctl", "station", Config.wirelessInterface, "connect", ssid]
                onExited: { ccWindow.wifiPendingSsid = ""; wifiRefreshProc.running = false; wifiRefreshProc.running = true }
            }
            Process { id: wifiDisconnectProc; command: ["iwctl", "station", Config.wirelessInterface, "disconnect"]; onExited: { wifiRefreshProc.running = false; wifiRefreshProc.running = true } }
            Process { id: wifiPowerProc; property string action: ""; command: ["rfkill", action, "wifi"]; onExited: { wifiRefreshProc.running = false; wifiRefreshProc.running = true } }

            function connectWifi(ssid, security) {
                if (security === "open" || wifiKnownSsids.indexOf(ssid) >= 0) {
                    wifiConnectProc.ssid = ssid; wifiConnectProc.passphrase = ""; wifiConnectProc.running = true
                } else {
                    ccWindow.wifiPendingSsid = ssid
                }
            }

            property bool btPowered: false
            property var btPairedDevices: []
            property var btNearbyDevices: []
            readonly property var btConnected: btPairedDevices.filter(function(d) { return d.connected })
            readonly property var btKnown: btPairedDevices.filter(function(d) { return !d.connected })
            readonly property var btScanActive: ccWindow.networkPollActive && ccWindow.networkSubTab === 2

            Process {
                id: btRefreshProc
                command: ["sh", "-c",
                    "bluetoothctl show 2>/dev/null | grep 'Powered:';"
                    + "echo '---PAIRED---';"
                    + "connected=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}');"
                    + "paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}');"
                    + "for mac in $paired; do"
                    + "  info=$(bluetoothctl info \"$mac\" 2>/dev/null);"
                    + "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2}');"
                    + "  [ -z \"$name\" ] && continue;"
                    + "  conn=0; echo \"$connected\" | grep -qx \"$mac\" && conn=1;"
                    + "  echo \"PAIRED|${mac}|${name}|${conn}\";"
                    + "done;"
                    + "echo '---NEARBY---';"
                    + "for mac in $(bluetoothctl devices 2>/dev/null | awk '{print $2}'); do"
                    + "  echo \"$paired\" | grep -qx \"$mac\" && continue;"
                    + "  info=$(bluetoothctl info \"$mac\" 2>/dev/null);"
                    + "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2}');"
                    + "  [ -z \"$name\" ] && continue;"
                    + "  echo \"$name\" | grep -qE '^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$' && continue;"
                    + "  echo \"NEARBY|${mac}|${name}\";"
                    + "done"]
                stdout: SplitParser {
                    property string section: ""
                    property var pairedList: []
                    property var nearbyList: []
                    onRead: data => {
                        var s = data.trim()
                        if (s === "---PAIRED---") { section = "paired"; pairedList = []; return }
                        if (s === "---NEARBY---") { section = "nearby"; nearbyList = []; return }
                        if (section === "") { ccWindow.btPowered = s.includes("Powered: yes"); return }
                        if (section === "paired" && s.startsWith("PAIRED|")) {
                            var parts = s.substring(7).split("|")
                            pairedList.push({ mac: parts[0] || "", name: parts[1] || "Unknown", connected: parts[2] === "1" })
                        }
                        if (section === "nearby" && s.startsWith("NEARBY|")) {
                            var parts = s.substring(7).split("|")
                            nearbyList.push({ mac: parts[0] || "", name: parts[1] || "Unknown" })
                        }
                    }
                }
                onExited: {
                    var paired = stdout.pairedList ?? []
                    paired.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    ccWindow.btPairedDevices = paired
                    var nearby = stdout.nearbyList ?? []
                    nearby.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    ccWindow.btNearbyDevices = nearby
                    stdout.section = ""
                    stdout.pairedList = []
                    stdout.nearbyList = []
                }
            }

            Timer {
                interval: 3000; repeat: true; running: ccWindow.networkPollActive
                onTriggered: { btRefreshProc.running = false; btRefreshProc.running = true }
                triggeredOnStart: true
            }

            // Long-running scan — piped stdin keeps bluetoothctl (and its D-Bus
            // connection) alive; killing the process auto-stops discovery. Only
            // runs while the Bluetooth sub-tab is actually open.
            Process {
                id: btScanProc
                running: ccWindow.btScanActive
                command: ["sh", "-c", "{ echo 'scan on'; sleep infinity; } | bluetoothctl"]
            }

            Process { id: btConnectProc; property string action: ""; property string mac: ""; command: ["bluetoothctl", action, mac]; onExited: { btRefreshProc.running = false; btRefreshProc.running = true } }
            Process { id: btPairConnectProc; property string mac: ""; command: ["sh", "-c", "bluetoothctl pair '" + mac + "' && bluetoothctl connect '" + mac + "'"]; onExited: { btRefreshProc.running = false; btRefreshProc.running = true } }
            Process { id: btPowerProc; property string state: ""; command: ["bluetoothctl", "power", state]; onExited: { btRefreshProc.running = false; btRefreshProc.running = true } }

            // ── Theme list ──
            property var themeList: []
            property string currentThemeName: ""
            // ~/.local/bin isn't on the Hyprland session's PATH, so Process
            // (unlike an interactive shell) can't resolve a bare "theme-set".
            readonly property string themeSetBin: "/home/" + Quickshell.env("USER") + "/.local/bin/theme-set"
            Process {
                id: themeListProc
                command: [ccWindow.themeSetBin, "--list"]
                stdout: StdioCollector {
                    onStreamFinished: ccWindow.themeList = this.text.trim().split("\n").filter(function(s) { return s !== "" })
                }
            }
            Process {
                id: currentThemeProc
                command: ["cat", "/home/" + Quickshell.env("USER") + "/.local/state/dotfiles-theme/current.name"]
                stdout: StdioCollector {
                    onStreamFinished: ccWindow.currentThemeName = this.text.trim()
                }
            }
            function refreshThemes() { themeListProc.running = true; currentThemeProc.running = true }

            onVisibleChanged: if (visible) { ccWindow.activeTab = 0; ccWindow.refreshThemes() }

            // ── Quick actions ──
            Process { id: screenshotProc; command: ["sh", "-c",
                "grim \"$(slurp)\" \"$HOME/Pictures/Screenshots/$(date +%Y-%m-%dT%H:%M:%S.%3N.png)\""
                + " && notify-send --icon=camera-photo 'Screenshot saved' \"Saved to $HOME/Pictures/Screenshots\""] }

            PopoutFrame {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: Config.gap
                width: Config.controlCentreWidth
                height: Math.max(ccCol.implicitHeight + 24, 420)
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: ccCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Digest — only abnormal state, else nothing. Icon logic
                    // mirrors BarNotifications.qml exactly, so the glyph never
                    // disagrees between the bar and here.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.notifSuppressed || root.storedNotifications.length > 0
                        spacing: 6
                        Text {
                            text: root.notifSuppressed ? "󰪑"
                                : root.storedNotifications.length > 0 ? "󰂚" : "󰂜"
                            font.family: Config.fontFamily; font.pixelSize: 14
                            color: Theme.subtle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.dndEnabled
                                ? "Do Not Disturb is on"
                                : root.autoDnd
                                    ? "Notifications silenced (fullscreen)"
                                    : root.storedNotifications.length + " unread notification" + (root.storedNotifications.length === 1 ? "" : "s")
                            font { family: Config.fontFamily; pixelSize: 11 }
                            color: Theme.subtle
                            elide: Text.ElideRight
                        }
                    }

                    // Quick actions: press-and-done only.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        QuickAction { icon: "󰄀"; label: "Screenshot"; onClicked: screenshotProc.running = true }
                        QuickAction {
                            readonly property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
                            icon: muted ? "󰝟" : "󰕾"
                            label: "Mute"
                            active: muted
                            onClicked: {
                                var sink = Pipewire.defaultAudioSink
                                if (sink?.audio) sink.audio.muted = !sink.audio.muted
                            }
                        }
                        QuickAction {
                            readonly property bool muted: Pipewire.defaultAudioSource?.audio?.muted ?? false
                            icon: muted ? "󰍭" : "󰍬"
                            label: "Mic"
                            active: muted
                            onClicked: {
                                var source = Pipewire.defaultAudioSource
                                if (source?.audio) source.audio.muted = !source.audio.muted
                            }
                        }
                        QuickAction {
                            icon: root.dndEnabled ? "󰪑" : "󰂜"
                            label: "DND"
                            active: root.dndEnabled
                            onClicked: root.dndEnabled = !root.dndEnabled
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

                    // Tab strip: navigate only, never toggles.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        CcTab { icon: "󰂜"; selected: ccWindow.activeTab === 0; onClicked: ccWindow.activeTab = 0
                            badge: root.storedNotifications.length > 0 ? root.storedNotifications.length : 0 }
                        CcTab { icon: "󰕾"; selected: ccWindow.activeTab === 1; onClicked: ccWindow.activeTab = 1 }
                        CcTab { icon: "󰛳"; selected: ccWindow.activeTab === 2; onClicked: ccWindow.activeTab = 2 }
                        CcTab { icon: "󰸌"; selected: ccWindow.activeTab === 3; onClicked: ccWindow.activeTab = 3 }
                    }

                    // ── Notifications tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: ccWindow.activeTab === 0
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.storedNotifications.length > 0
                            Item { Layout.fillWidth: true }
                            CcLinkButton { text: "Clear all"; onClicked: root.clearAllNotifications() }
                        }

                        Text {
                            visible: root.storedNotifications.length === 0
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            horizontalAlignment: Text.AlignHCenter
                            text: "No notifications"
                            font { family: Config.fontFamily; pixelSize: 12 }
                            color: Theme.subtle
                        }

                        Item {
                            visible: root.storedNotifications.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(notifCol.implicitHeight, 320)

                            Flickable {
                                id: notifFlick
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: notifCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: notifCol
                                    width: notifFlick.width
                                    spacing: 6

                                    Repeater {
                                        model: root.storedNotifications.length
                                        delegate: Rectangle {
                                            id: nRow
                                            required property int index
                                            readonly property var n: root.storedNotifications[index]
                                            Layout.fillWidth: true
                                            implicitHeight: nRowCol.implicitHeight + 16
                                            radius: Config.radiusCell
                                            color: Theme.elev2

                                            ColumnLayout {
                                                id: nRowCol
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 2
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Text {
                                                        text: nRow.n.appName || "Notification"
                                                        font { family: Config.fontFamily; pixelSize: 11 }
                                                        color: Theme.subtle
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Rectangle {
                                                        width: 16; height: 16; radius: Config.radiusCell
                                                        color: nCloseMA.containsMouse ? Theme.hover : "transparent"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "󰅖"; font.family: Config.fontFamily; font.pixelSize: 11
                                                            color: nCloseMA.containsMouse ? Theme.red : Theme.subtle
                                                        }
                                                        MouseArea { id: nCloseMA; anchors.fill: parent; hoverEnabled: true
                                                            onClicked: root.dismissStoredNotification(nRow.n) }
                                                    }
                                                }
                                                Text {
                                                    visible: (nRow.n.summary ?? "") !== ""
                                                    text: nRow.n.summary ?? ""
                                                    font { family: Config.fontFamily; pixelSize: 12; bold: true }
                                                    color: Theme.text
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    visible: (nRow.n.body ?? "") !== ""
                                                    text: nRow.n.body ?? ""
                                                    font { family: Config.fontFamily; pixelSize: 11 }
                                                    color: Theme.subtle
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            OverlayScrollBar { flickable: notifFlick }
                        }
                    }

                    // ── Audio tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: ccWindow.activeTab === 1
                        spacing: 8

                        Text { text: "Output"; font.family: Config.fontFamily; font.pixelSize: 11; font.bold: true; color: Theme.subtle }
                        Repeater {
                            model: Pipewire.nodes
                            delegate: CcAudioRow {
                                required property var modelData
                                node: modelData
                                isDefault: modelData === Pipewire.defaultAudioSink
                                accentColor: Theme.volumeColor
                                visible: modelData.isSink && !modelData.isStream
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                onSetDefault: Pipewire.preferredDefaultAudioSink = modelData
                                onSetVolume: value => root.setPanelVolume(modelData, value)
                                onToggleMute: modelData.audio.muted = !modelData.audio.muted
                            }
                        }

                        Text { text: "Input"; font.family: Config.fontFamily; font.pixelSize: 11; font.bold: true; color: Theme.subtle; Layout.topMargin: 4 }
                        Text {
                            visible: ccWindow.audioSourceCount === 0
                            text: "No devices"
                            font.family: Config.fontFamily; font.pixelSize: 11
                            color: Theme.subtle
                        }
                        Repeater {
                            model: Pipewire.nodes
                            delegate: CcAudioRow {
                                required property var modelData
                                node: modelData
                                isDefault: modelData === Pipewire.defaultAudioSource
                                accentColor: Theme.microphoneColor
                                visible: !modelData.isSink && !modelData.isStream && modelData.audio
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                onSetDefault: Pipewire.preferredDefaultAudioSource = modelData
                                onSetVolume: value => root.setPanelMicVolume(modelData, value)
                                onToggleMute: modelData.audio.muted = !modelData.audio.muted
                            }
                        }
                    }

                    // ── Network tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: ccWindow.activeTab === 2
                        spacing: 8

                        RowLayout {
                            spacing: 2
                            CcSubTab { text: "Ethernet"; selected: ccWindow.networkSubTab === 0; onClicked: ccWindow.networkSubTab = 0 }
                            CcSubTab { text: "Wi-Fi"; selected: ccWindow.networkSubTab === 1; onClicked: ccWindow.networkSubTab = 1 }
                            CcSubTab { text: "Bluetooth"; selected: ccWindow.networkSubTab === 2; onClicked: ccWindow.networkSubTab = 2 }
                        }

                        // Ethernet — info + enable/disable only, no per-network list.
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: ccWindow.networkSubTab === 0
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Ethernet"; Layout.fillWidth: true; font.family: Config.fontFamily; font.pixelSize: 12; color: Theme.text }
                                CcToggleChip {
                                    on: ccWindow.ethUp
                                    onClicked: { ethToggleProc.action = ccWindow.ethUp ? "down" : "up"; ethToggleProc.running = true }
                                }
                            }

                            CcNetworkRow {
                                Layout.fillWidth: true
                                label: Config.ethernetInterface + (ccWindow.ethUp && ccWindow.ethIpAddr ? "  " + ccWindow.ethIpAddr : "")
                                connected: ccWindow.ethUp
                                secure: false
                                accentColor: Theme.ethernetColor
                            }
                        }

                        // Wi-Fi
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: ccWindow.networkSubTab === 1
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Wi-Fi"; Layout.fillWidth: true; font.family: Config.fontFamily; font.pixelSize: 12; color: Theme.text }
                                CcToggleChip {
                                    on: ccWindow.wifiPowered
                                    onClicked: { wifiPowerProc.action = ccWindow.wifiPowered ? "block" : "unblock"; wifiPowerProc.running = true }
                                }
                            }

                            Repeater {
                                model: ccWindow.wifiConnected.concat(ccWindow.wifiAvailable).length
                                delegate: CcNetworkRow {
                                    required property int index
                                    readonly property var net: ccWindow.wifiConnected.concat(ccWindow.wifiAvailable)[index]
                                    Layout.fillWidth: true
                                    label: net.ssid
                                    connected: net.connected
                                    secure: net.security !== "open"
                                    accentColor: Theme.wirelessColor
                                    showPassword: ccWindow.wifiPendingSsid === net.ssid
                                    onToggle: net.connected ? wifiDisconnectProc.running = true : ccWindow.connectWifi(net.ssid, net.security)
                                    onSubmitPassword: pass => { wifiConnectProc.ssid = net.ssid; wifiConnectProc.passphrase = pass; wifiConnectProc.running = true }
                                }
                            }
                        }

                        // Bluetooth — connected → known (paired) → unknown (nearby), same
                        // ordering as BluetoothPanel.
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: ccWindow.networkSubTab === 2
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Bluetooth"; Layout.fillWidth: true; font.family: Config.fontFamily; font.pixelSize: 12; color: Theme.text }
                                CcToggleChip {
                                    on: ccWindow.btPowered
                                    onClicked: { btPowerProc.state = ccWindow.btPowered ? "off" : "on"; btPowerProc.running = true }
                                }
                            }

                            Repeater {
                                model: ccWindow.btConnected.length
                                delegate: CcNetworkRow {
                                    required property int index
                                    readonly property var dev: ccWindow.btConnected[index]
                                    Layout.fillWidth: true
                                    label: dev.name
                                    connected: true
                                    secure: false
                                    accentColor: Theme.bluetoothColor
                                    onToggle: { btConnectProc.action = "disconnect"; btConnectProc.mac = dev.mac; btConnectProc.running = true }
                                }
                            }
                            Repeater {
                                model: ccWindow.btKnown.length
                                delegate: CcNetworkRow {
                                    required property int index
                                    readonly property var dev: ccWindow.btKnown[index]
                                    Layout.fillWidth: true
                                    label: dev.name
                                    connected: false
                                    secure: false
                                    accentColor: Theme.bluetoothColor
                                    onToggle: { btConnectProc.action = "connect"; btConnectProc.mac = dev.mac; btConnectProc.running = true }
                                }
                            }
                            Repeater {
                                model: ccWindow.btNearbyDevices.length
                                delegate: CcNetworkRow {
                                    required property int index
                                    readonly property var dev: ccWindow.btNearbyDevices[index]
                                    Layout.fillWidth: true
                                    label: dev.name
                                    connected: false
                                    secure: false
                                    accentColor: Theme.bluetoothColor
                                    onToggle: { btPairConnectProc.mac = dev.mac; btPairConnectProc.running = true }
                                }
                            }
                        }
                    }

                    // ── Themes tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: ccWindow.activeTab === 3
                        spacing: 4

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(themeCol.implicitHeight, 280)

                            Flickable {
                                id: themeFlick
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: themeCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: themeCol
                                    width: themeFlick.width
                                    spacing: 2

                                    Repeater {
                                        model: ccWindow.themeList
                                        delegate: Rectangle {
                                            id: themeRow
                                            required property string modelData
                                            readonly property bool isCurrent: modelData === ccWindow.currentThemeName
                                            Layout.fillWidth: true
                                            height: 28
                                            radius: Config.radiusCell
                                            color: themeRow.isCurrent
                                                ? (themeMA.containsMouse ? Theme.press : Theme.elev2)
                                                : (themeMA.containsMouse ? Theme.hover : "transparent")
                                            border.width: themeRow.isCurrent ? 1 : 0
                                            border.color: Theme.accent

                                            Text {
                                                anchors.left: parent.left; anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: themeRow.modelData
                                                font { family: Config.fontFamily; pixelSize: 12 }
                                                color: themeRow.isCurrent ? Theme.accent : (themeMA.containsMouse ? Theme.text : Theme.subtle)
                                            }

                                            MouseArea {
                                                id: themeMA
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    themeApplyProc.command = [ccWindow.themeSetBin, themeRow.modelData]
                                                    themeApplyProc.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            OverlayScrollBar { flickable: themeFlick }
                        }
                    }

                    // Soaks up the panel's fixed minimum height (rule below)
                    // so leftover space collects here instead of being spread
                    // as gaps between every row — Qt Quick Layouts distributes
                    // unclaimed space evenly across children unless one of
                    // them claims it via fillHeight.
                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                }
            }
        }
    }

    Process { id: themeApplyProc; running: false }

    // ── Shared sub-components ──

    component QuickAction: Rectangle {
        id: qa
        property string icon: ""
        property string label: ""
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        height: 30
        radius: Config.radiusCell
        color: qa.active
            ? (qaMA.containsMouse ? Theme.press : Theme.elev2)
            : (qaMA.containsMouse ? Theme.hover : "transparent")
        border.width: 1
        border.color: qa.active ? Theme.accent : Theme.edge

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qa.icon
                font.family: Config.fontFamily; font.pixelSize: 14
                color: qa.active ? Theme.accent : (qaMA.containsMouse ? Theme.text : Theme.subtle)
            }
        }

        MouseArea { id: qaMA; anchors.fill: parent; hoverEnabled: true; onClicked: qa.clicked() }
    }

    component CcTab: Item {
        id: tab
        property string icon: ""
        property bool selected: false
        property int badge: 0
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: Config.radiusCell
            color: tab.selected
                ? (tabMA.containsMouse ? Theme.press : Theme.elev2)
                : (tabMA.containsMouse ? Theme.hover : "transparent")
            border.width: tab.selected ? 1 : 0
            border.color: Theme.accent
        }
        Text {
            anchors.centerIn: parent
            text: tab.icon
            font.family: Config.fontFamily; font.pixelSize: 15
            color: tab.selected ? Theme.accent : (tabMA.containsMouse ? Theme.text : Theme.subtle)
        }
        Rectangle {
            visible: tab.badge > 0
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: 2; anchors.rightMargin: 2
            width: 8; height: 8; radius: 4
            color: Theme.redDim
        }
        MouseArea { id: tabMA; anchors.fill: parent; hoverEnabled: true; onClicked: tab.clicked() }
    }

    component CcSubTab: Item {
        id: subTab
        property string text: ""
        property bool selected: false
        signal clicked()
        implicitWidth: subTabText.implicitWidth + 16
        implicitHeight: 22

        Rectangle {
            anchors.fill: parent
            radius: Config.radiusCell
            color: subTab.selected
                ? (subTabMA.containsMouse ? Theme.press : Theme.elev2)
                : (subTabMA.containsMouse ? Theme.hover : "transparent")
            border.width: subTab.selected ? 1 : 0
            border.color: Theme.accent
        }
        Text {
            id: subTabText
            anchors.centerIn: parent
            text: subTab.text
            font { family: Config.fontFamily; pixelSize: 11 }
            color: subTab.selected ? Theme.accent : (subTabMA.containsMouse ? Theme.text : Theme.subtle)
        }
        MouseArea { id: subTabMA; anchors.fill: parent; hoverEnabled: true; onClicked: subTab.clicked() }
    }

    component CcLinkButton: Text {
        id: link
        property alias text: link.text
        signal clicked()
        font { family: Config.fontFamily; pixelSize: 11 }
        color: linkMA.containsMouse ? Theme.text : Theme.subtle
        MouseArea { id: linkMA; anchors.fill: parent; hoverEnabled: true; onClicked: link.clicked() }
    }

    component CcToggleChip: Rectangle {
        id: chip
        property bool on: false
        signal clicked()
        width: chipText.implicitWidth + 16
        height: 20
        radius: 10
        color: chip.on
            ? (chipMA.containsMouse ? Theme.press : Theme.elev2)
            : (chipMA.containsMouse ? Theme.hover : "transparent")
        border.width: 1
        border.color: chip.on ? Theme.accent : Theme.edge
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.on ? "On" : "Off"
            font { family: Config.fontFamily; pixelSize: 10 }
            color: chip.on ? Theme.accent : Theme.subtle
        }
        MouseArea { id: chipMA; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
    }

    component CcAudioRow: Rectangle {
        id: audioRow
        property var node
        property bool isDefault: false
        property color accentColor: Theme.accent
        readonly property real nodeVol: node.audio?.volume ?? 0
        readonly property bool nodeMuted: node.audio?.muted ?? false
        signal setDefault()
        signal setVolume(real value)
        signal toggleMute()

        implicitHeight: visible ? rowCol.implicitHeight + 12 : 0
        radius: Config.radiusCell
        color: isDefault
            ? (audioMA.containsMouse ? Theme.press : Theme.elev2)
            : (audioMA.containsMouse ? Theme.hover : "transparent")
        border.width: isDefault ? 1 : 0
        border.color: audioRow.accentColor

        ColumnLayout {
            id: rowCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: audioRow.nodeMuted ? "󰝟" : "󰕾"
                    font.family: Config.fontFamily; font.pixelSize: 13
                    color: audioRow.isDefault ? audioRow.accentColor : (audioRow.nodeMuted ? Theme.muted : Theme.subtle)
                }
                Text {
                    text: audioRow.node.description || audioRow.node.name || "Unknown"
                    font { family: Config.fontFamily; pixelSize: 12 }
                    color: audioRow.isDefault || audioMA.containsMouse ? Theme.text : Theme.subtle
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: audioMA.containsMouse
                    text: Math.round(audioRow.nodeVol * 100) + "%"
                    font { family: Config.fontFamily; pixelSize: 11; features: { "tnum": 1 } }
                    color: Theme.subtle
                }
            }

            Rectangle {
                id: slider
                Layout.fillWidth: true
                height: 5; radius: 2.5
                color: audioMA.containsMouse ? Theme.hover : Theme.divider
                Rectangle {
                    width: parent.width * Math.min(audioRow.nodeVol, 1.0)
                    height: parent.height; radius: parent.radius
                    color: audioRow.nodeMuted ? Theme.muted : audioRow.accentColor
                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: audioMA
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property bool adjusting: false
            function setFromMouse(mouse) {
                var p = slider.mapToItem(audioRow, 0, 0)
                audioRow.setVolume((mouse.x - p.x) / slider.width)
            }
            onPressed: mouse => {
                var p = slider.mapToItem(audioRow, 0, 0)
                adjusting = mouse.button === Qt.LeftButton
                    && mouse.y >= p.y - 6 && mouse.y <= p.y + slider.height + 6
                if (adjusting) setFromMouse(mouse)
            }
            onPositionChanged: mouse => { if (adjusting && pressed) setFromMouse(mouse) }
            onReleased: adjusting = false
            onClicked: mouse => {
                if (adjusting) return
                if (mouse.button === Qt.RightButton) audioRow.toggleMute()
                else if (!audioRow.isDefault) audioRow.setDefault()
            }
            onWheel: wheel => {
                if (!audioRow.node.audio) return
                var step = 0.05
                if (wheel.angleDelta.y > 0) audioRow.setVolume(audioRow.nodeVol + step)
                else if (wheel.angleDelta.y < 0) audioRow.setVolume(audioRow.nodeVol - step)
            }
        }
    }

    component CcNetworkRow: ColumnLayout {
        id: netRow
        property string label: ""
        property bool connected: false
        property bool secure: false
        property color accentColor: Theme.accent
        property bool showPassword: false
        signal toggle()
        signal submitPassword(string password)
        spacing: 2

        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: Config.radiusCell
            color: netRow.connected
                ? (netMA.containsMouse ? Theme.press : Theme.elev2)
                : (netMA.containsMouse ? Theme.hover : "transparent")
            border.width: netRow.connected ? 1 : 0
            border.color: netRow.accentColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 6
                Text {
                    text: netRow.label
                    font { family: Config.fontFamily; pixelSize: 12 }
                    color: netRow.connected || netMA.containsMouse ? Theme.text : Theme.subtle
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: netRow.secure
                    text: "󰌆"; font.family: Config.fontFamily; font.pixelSize: 11; color: Theme.subtle
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: netRow.connected ? netRow.accentColor : Theme.muted
                }
            }

            MouseArea { id: netMA; anchors.fill: parent; hoverEnabled: true; onClicked: netRow.toggle() }
        }

        RowLayout {
            visible: netRow.showPassword
            Layout.fillWidth: true
            spacing: 6
            TextInput {
                id: ccPassInput
                Layout.fillWidth: true
                font { family: Config.fontFamily; pixelSize: 12 }
                color: Theme.text
                echoMode: TextInput.Password
                onAccepted: netRow.submitPassword(text)
                onVisibleChanged: if (visible) forceActiveFocus()
            }
            Text {
                text: "󰌑"
                font { family: Config.fontFamily; pixelSize: 13 }
                color: ccPassMA.containsMouse ? netRow.accentColor : Theme.subtle
                MouseArea { id: ccPassMA; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                    onClicked: netRow.submitPassword(ccPassInput.text) }
            }
        }
    }
}
