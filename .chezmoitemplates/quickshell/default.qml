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

    property string workspaceStyle: "outline" // "outline", "background" or "icon"
    property bool enableWorkspaceTransition: true
    // Right-click a workspace to move it to the other monitor. When true,
    // also switch focus to it there; when false, it moves but stays
    // unfocused wherever you currently are.
    property bool workspaceMoveFollowsFocus: true
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
    property int gap: 6
    property int barWidth: 48
    readonly property int effectiveBarWidth: barIslands ? barWidth + gap : barWidth
    property int edgeInset: 10
    property int radiusCell: 6
    property int radiusIsland: 10
    property int radiusPopout: 14
    property bool popoutHalo: true
    property string osdPosition: "top"
    property string fontFamily: "NotoSans Nerd Font"

    // "state": icons rest at `subtle`, only take on their accent hue when they
    // have something to report. "always": today's behaviour — per-component
    // hue at rest, greying out on muted/disconnected.
    property string barAccentPolicy: "state"

    property bool barIdleDim: false
    property int barIdleTimeout: 120000 // ms
    property real barIdleOpacity: 0.55

    // Third-party tray/notification-app icons are full-colour bitmaps outside
    // the theme system. "native": untouched. "desaturate": grey at rest, full
    // colour on hover. "dim": opacity 0.75 at rest, 1.0 on hover.
    property string trayIconStyle: "native"

    property int osdDuration: 1500
    property int osdStartupDelay: 2000
    property int tooltipHideDelay: 300
    property int networkPollFallback: 60000

    property bool suppressInFullscreen: true
    property bool suppressRequiresPlayback: false

    property int notifPanelWidth: 360
    property int notifPanelHeight: 420
    property int maxStoredNotifications: 20
    // Set above 1 to stack multiple live toasts. Set to 0 to disable them.
    property int maxLiveNotificationToasts: 1
    // 2px hairline on normal-urgency toasts showing time until auto-expire.
    property bool toastProgressHairline: true
    // Collapse consecutive same-app notifications in the centre into one
    // expandable card. Grouping is by app identity (whatever the sender set
    // as its name over DBus), not message content — tools that default to a
    // generic name when called without an explicit app name (e.g. plain
    // `notify-send` without -a) will group together even with different text.
    property bool groupNotifications: true

    property string volumeApp: "pwvucontrol"
    property string wirelessApp: "iwgtk"
    property string bluetoothApp: "blueman-manager"
    property string wirelessToggleScript: ""
    property string bluetoothToggleScript: ""
}
