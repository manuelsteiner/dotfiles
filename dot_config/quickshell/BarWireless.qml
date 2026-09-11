import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

BarCell {
    id: netBlock
    Layout.alignment: Qt.AlignHCenter
    property var screen: null
    property string iface: Config.wirelessInterface
    property bool up: false
    property string essid: ""
    property int signal: 0
    property string ipAddr: ""
    hovered: netMA.containsMouse
    pressed: netMA.pressed
    // Bluetooth-style everywhere: accent when actually connected, subtle
    // when not, regardless of barAccentPolicy — there's no meaningful
    // "always vs state" distinction for a link that's simply up or down.
    active: netBlock.up
    urgent: false
    accentColor: Theme.wirelessColor

    Process {
        id: netRefreshProc
        command: ["sh", "-c",
            "cat /sys/class/net/" + netBlock.iface + "/operstate 2>/dev/null;"
            + "echo '---IWCTL---';"
            + "iwctl station " + netBlock.iface + " show 2>/dev/null"
            + " | awk '"
            + " /Connected network/{sub(/.*Connected network */, \"\"); print \"SSID:\"$0}"
            + " /IPv4 address/{sub(/.*IPv4 address */, \"\"); print \"IP:\"$0}"
            + " /^[[:space:]]*RSSI/{sub(/.*RSSI */, \"\"); print \"SIG:\"$0}"
            + "'"]
        stdout: SplitParser {
            property bool inIwctl: false
            onRead: data => {
                var s = data.trim()
                if (s === "---IWCTL---") { inIwctl = true; return }
                if (!inIwctl) {
                    netBlock.up = s === "up"
                    if (!netBlock.up) {
                        netBlock.essid = ""
                        netBlock.signal = 0
                        netBlock.ipAddr = ""
                    }
                }
                if (inIwctl && s.startsWith("SSID:")) netBlock.essid = s.substring(5).trim()
                if (inIwctl && s.startsWith("IP:")) netBlock.ipAddr = s.substring(3).trim()
                if (inIwctl && s.startsWith("SIG:")) {
                    var dbm = parseInt(s.substring(4))
                    if (!isNaN(dbm))
                        netBlock.signal = Math.min(100, Math.max(0, 2 * (dbm + 100)))
                }
            }
        }
        onExited: { stdout.inIwctl = false }
    }

    Process {
        id: rfkillWatcher
        command: ["sh", "-c",
            "stdbuf -oL udevadm monitor --kernel --subsystem-match=rfkill 2>/dev/null"
            + " | while IFS= read -r line; do echo REFRESH; done"]
        running: true
        stdout: SplitParser {
            onRead: data => { if (data.trim() === "REFRESH") netDebounce.restart() }
        }
    }

    Process {
        id: ipWatcher
        command: ["ip", "monitor", "link", "address", "dev", netBlock.iface]
        running: true
        stdout: SplitParser {
            onRead: data => { netDebounce.restart() }
        }
    }

    Timer {
        id: netDebounce
        interval: 500
        onTriggered: {
            netRefreshProc.running = false
            netRefreshProc.running = true
        }
    }

    Component.onCompleted: netRefreshProc.running = true

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: netBlock.glyphColor
        text: netBlock.up ? "󰖩" : "󰖪"
    }

    MouseArea {
        id: netMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && Config.wirelessToggleScript !== "")
                wirelessToggle.running = true
            else if (mouse.button === Qt.LeftButton) {
                if (Config.enableWirelessPanel) {
                    var pos = netBlock.mapToItem(null, 0, netBlock.height / 2)
                    root.toggleWifiPanel(pos.y, netBlock.screen)
                } else {
                    netAppProc.running = true
                }
            }
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                var tip = netBlock.up
                    ? (netBlock.essid || "Connected")
                      + (netBlock.signal > 0 ? " (" + netBlock.signal + "%)" : "")
                      + (netBlock.ipAddr ? "\n" + netBlock.ipAddr : "")
                    : "Disconnected"
                root.showTooltip("net", tip, pos.y)
            } else {
                root.hideTooltip("net")
            }
        }
    }

    Process { id: netAppProc; command: [Config.wirelessApp]; running: false }
    Process { id: wirelessToggle; command: [Config.wirelessToggleScript]; running: false }
}
