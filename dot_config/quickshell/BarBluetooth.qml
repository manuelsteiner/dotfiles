import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btBlock
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: 36; radius: 6
    property bool powered: false
    property var connectedDevices: []  // [{name, battery}]
    color: btMA.containsMouse
        ? (btBlock.powered ? Theme.bluetoothColor : Theme.muted)
        : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Process {
        id: btRefreshProc
        command: ["sh", "-c",
            "echo '---POWER---';"
            + "bluetoothctl show 2>/dev/null | grep 'Powered:';"
            + "echo '---DEVS---';"
            + "for mac in $(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); do"
            + "  info=$(bluetoothctl info \"$mac\" 2>/dev/null);"
            + "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2}');"
            + "  bat=$(echo \"$info\" | awk -F'[(): ]' '/Battery Percentage:/{for(i=1;i<=NF;i++) if($i~/^[0-9]+$/) print $i}');"
            + "  [ -z \"$name\" ] && continue;"
            + "  echo \"DEV:${name}:${bat}\";"
            + "done"]
        stdout: SplitParser {
            property bool inDevs: false
            property var devs: []
            onRead: data => {
                var s = data.trim()
                if (s === "---POWER---") { inDevs = false; return }
                if (s === "---DEVS---") { inDevs = true; devs = []; return }
                if (!inDevs && s.includes("Powered: yes")) btBlock.powered = true
                else if (!inDevs && s.includes("Powered: no")) btBlock.powered = false
                if (inDevs && s.startsWith("DEV:")) {
                    var parts = s.substring(4).split(":")
                    var name = parts[0] || "Unknown"
                    var bat = parts[1] ? parseInt(parts[1]) : -1
                    devs.push({name: name, battery: bat})
                }
            }
        }
        onExited: {
            btBlock.connectedDevices = stdout.devs ?? []
            stdout.devs = []
        }
    }

    Process {
        id: btWatcher
        command: ["sh", "-c",
            "dbus-monitor --system"
            + " \"type='signal',sender='org.bluez',"
            + "interface='org.freedesktop.DBus.Properties',"
            + "member='PropertiesChanged'\""
            + " 2>/dev/null"
            + " | while read -r line; do"
            + "   case \"$line\" in *PropertiesChanged*) echo REFRESH;; esac;"
            + " done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "REFRESH") btRefreshProc.running = true
            }
        }
    }

    Component.onCompleted: btRefreshProc.running = true

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: btMA.containsMouse ? Theme.base
            : btBlock.powered ? Theme.bluetoothColor : Theme.muted
        text: btBlock.powered ? "󰂯" : "󰂲"
    }

    MouseArea {
        id: btMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && Config.bluetoothToggleScript !== "")
                btToggleProc.running = true
            else if (mouse.button === Qt.LeftButton && Config.enableBluetoothPanel) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.toggleBtPanel(pos.y)
            } else if (mouse.button === Qt.LeftButton)
                btAppProc.running = true
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                var tip
                if (btBlock.connectedDevices.length > 0) {
                    var lines = btBlock.connectedDevices.map(function(d) {
                        return d.battery >= 0 ? d.name + " (" + d.battery + "%)" : d.name
                    })
                    tip = lines.join("\n")
                } else {
                    tip = btBlock.powered ? "No devices" : "Bluetooth off"
                }
                root.showTooltip("bt", tip, pos.y)
            } else {
                root.hideTooltip("bt")
            }
        }
    }

    Process { id: btAppProc; command: [Config.bluetoothApp]; running: false }
    Process { id: btToggleProc; command: [Config.bluetoothToggleScript]; running: false }
}
