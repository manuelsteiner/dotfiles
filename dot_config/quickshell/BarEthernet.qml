import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: ethBlock
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: 36; radius: 6
    property string iface: Config.ethernetInterface
    property bool up: false
    property string ipAddr: ""
    color: ethMA.containsMouse
        ? (ethBlock.up ? Theme.ethernetColor : Theme.muted)
        : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Process {
        id: ethRefreshProc
        command: ["sh", "-c",
            "cat /sys/class/net/" + ethBlock.iface + "/operstate 2>/dev/null;"
            + "echo '---IP---';"
            + "ip -4 addr show " + ethBlock.iface + " 2>/dev/null"
            + " | awk '/inet /{split($2,a,\"/\"); print \"IP:\"a[1]}'"]
        stdout: SplitParser {
            property bool inIp: false
            onRead: data => {
                var s = data.trim()
                if (s === "---IP---") { inIp = true; return }
                if (!inIp) {
                    ethBlock.up = s === "up"
                    if (!ethBlock.up) ethBlock.ipAddr = ""
                }
                if (inIp && s.startsWith("IP:")) ethBlock.ipAddr = s.substring(3).trim()
            }
        }
        onExited: { stdout.inIp = false }
    }

    Process {
        id: ethWatcher
        command: ["sh", "-c",
            "stdbuf -oL udevadm monitor --kernel --subsystem-match=net 2>/dev/null"
            + " | while read -r line; do"
            + "   case \"$line\" in *" + ethBlock.iface + "*) echo REFRESH;; esac;"
            + " done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "REFRESH") ethRefreshProc.running = true
            }
        }
    }

    Component.onCompleted: ethRefreshProc.running = true
    Timer {
        interval: Config.networkPollFallback
        running: true; repeat: true
        onTriggered: ethRefreshProc.running = true
    }

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: ethMA.containsMouse ? Theme.base
            : ethBlock.up ? Theme.ethernetColor : Theme.muted
        text: ethBlock.up ? "󰈀" : "󰈂"
    }

    MouseArea {
        id: ethMA
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                var tip = ethBlock.up
                    ? ethBlock.iface
                      + (ethBlock.ipAddr ? "\n" + ethBlock.ipAddr : "")
                    : ethBlock.iface + " (disconnected)"
                root.showTooltip("eth", tip, pos.y)
            } else {
                root.hideTooltip("eth")
            }
        }
    }
}
