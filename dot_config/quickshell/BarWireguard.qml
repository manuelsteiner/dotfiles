import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: wgBlock
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: 36; radius: 6

    property var tunnels: []
    property bool anyUp: tunnels.some(t => t.up)

    color: wgMA.containsMouse
        ? (wgBlock.anyUp ? Theme.wireguardColor : Theme.muted)
        : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

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

    Process {
        id: wgRefreshProc
        command: ["sh", "-c", wgBlock.buildRefreshCmd()]
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
            wgBlock.tunnels = r
            stdout.results = []
            stdout.currentIface = ""
            stdout.currentUp = false
            stdout.currentIp = ""
        }
    }

    Process {
        id: wgWatcher
        command: {
            var ifaces = Config.wireguardInterfaces
            var cases = ifaces.map(function(i) { return "*" + i + "*" }).join("|")
            return ["sh", "-c",
                "stdbuf -oL ip monitor link 2>/dev/null"
                + " | while read -r line; do"
                + "   case \"$line\" in " + cases + ") echo REFRESH;; esac;"
                + " done"]
        }
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "REFRESH") wgRefreshProc.running = true
            }
        }
    }

    Component.onCompleted: wgRefreshProc.running = true
    Timer {
        interval: Config.networkPollFallback
        running: true; repeat: true
        onTriggered: wgRefreshProc.running = true
    }

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: wgMA.containsMouse ? Theme.base
            : wgBlock.anyUp ? Theme.wireguardColor : Theme.muted
        text: "󰴳"
    }

    MouseArea {
        id: wgMA
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (Config.enableWireguardPanel) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.toggleWgPanel(pos.y)
            }
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                var lines = []
                for (var i = 0; i < wgBlock.tunnels.length; i++) {
                    var t = wgBlock.tunnels[i]
                    if (t.up) {
                        lines.push(t.iface + (t.ip ? " — " + t.ip : ""))
                    } else {
                        lines.push(t.iface + " (down)")
                    }
                }
                var tip = lines.length > 0 ? lines.join("\n") : "No tunnels configured"
                root.showTooltip("wg", tip, pos.y)
            } else {
                root.hideTooltip("wg")
            }
        }
    }
}
