pragma Singleton
import Quickshell

Singleton {
    property bool enableClock: true
    property bool enableWorkspaces: true
    property bool enableSystemTray: true
    property bool enableVolume: true
    property bool enableMicrophone: true
    property bool enableEthernet: true
    property bool enableWireless: true
    property bool enableWireguard: true
    property bool enableBluetooth: true
    property bool hideDisconnectedEthernet: true
    property bool hideDisconnectedWireless: false
    property bool hideDisconnectedBluetooth: false
    property bool hideDisconnectedWireguard: false
    property bool enableBrightness: false
    property bool enableBattery: false
    property bool enableNotifications: true
    property bool enableVolumeOsd: true
    property bool enableMicrophoneOsd: true
    property bool enableBrightnessOsd: true
    property bool enableVolumeBar: false
    property bool enableMicrophoneBar: false
    property bool enableBrightnessBar: false
    property bool enableVolumePanel: true
    property bool enableMicrophonePanel: true
    property bool enableWirelessPanel: true
    property bool enableBluetoothPanel: true
    property bool enableWireguardPanel: true
    property bool enableCalendar: true
    property bool enablePower: true

    property string ethernetInterface: "enp86s0"
    property string wirelessInterface: "wlan0"
    property var wireguardInterfaces: ["wg-mts"]

    property string workspaceStyle: "background"
    property bool enableWorkspaceTransition: true
    property var workspaces: [
        { ws: 1, icon: "" },
        { ws: 2, icon: "󰈹" },
        { ws: 3, icon: "󰭹" },
        { ws: 4, icon: "󰠮" },
        { ws: 5, icon: "󱜐" },
        { ws: 6, icon: "󰕰" },
        { ws: 7, icon: "󰢹" },
    ]

    // "default" uses the active theme's preferred accent. Set any palette
    // role here to override it: red, yellow, orange, blue, cyan, magenta.
    property string accentColor: "default"
    property string volumeAccent: "magenta"
    property string microphoneAccent: "magenta"
    property string bluetoothAccent: "cyan"
    property string ethernetAccent: "blue"
    property string wirelessAccent: "blue"
    property string wireguardAccent: "blue"
    property string brightnessAccent: "yellow"
    property string notificationAccent: "orange"
    property string powerAccent: "red"
    property string urgentAccent: "red"

    property bool barIslands: true
    property int barGap: 6
    property int barWidth: 48
    readonly property int effectiveBarWidth: barIslands ? barWidth + barGap : barWidth
    property string osdPosition: "top"
    property string fontFamily: "NotoSans Nerd Font"

    property int osdDuration: 1500
    property int osdStartupDelay: 2000
    property int tooltipHideDelay: 300
    property int networkPollFallback: 60000

    property bool suppressInFullscreen: true
    property bool suppressRequiresPlayback: false

    property int notifPanelWidth: 360
    property int notifPanelHeight: 420
    property int maxStoredNotifications: 20

    property string volumeApp: "pwvucontrol"
    property string wirelessApp: "iwgtk"
    property string bluetoothApp: "blueman-manager"
    property string wirelessToggleScript: ""
    property string bluetoothToggleScript: ""
}
