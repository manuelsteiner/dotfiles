pragma Singleton
import Quickshell

Singleton {
    // ── Feature toggles ──
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
    property bool enableBattery: true
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

    // ── Network ──
    property string ethernetInterface: "enp0s13f0u3c2"
    property string wirelessInterface: "wlan0"
    property var wireguardInterfaces: ["wg-home", "wg-mts"]

    // ── Workspaces ──
    property string workspaceStyle: "outline" // "outline", "background" (accent bg) or "icon" (accent icon)
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

    // ── Appearance ──
    property string accentColor: "default" // default, red, yellow, orange, blue, cyan, magenta
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

    // ── Bar layout ──
    property bool barIslands: true
    property int gap: 6
    property int barWidth: 48
    readonly property int effectiveBarWidth: barIslands ? barWidth + gap : barWidth
    property int edgeInset: 10
    property int radiusCell: 6
    property int radiusIsland: 10
    property int radiusPopout: 14
    property bool popoutHalo: true

    // Normal-theme elevation. Theme.qml lifts these to 0.07 and 0.10 only
    // for the shared OLED category, whose palettes use a pure-black base.
    property real elev1Alpha: 0.04
    property real elev2Alpha: 0.07
    property real edgeAlpha: 0.18

    property string osdPosition: "top" // "top", "center", "bottom"
    property string fontFamily: "Noto Nerd Font"

    // "state": icons rest at `subtle`, only take on their accent hue when they
    // have something to report. "always": today's behaviour — per-component
    // hue at rest, greying out on muted/disconnected.
    property string barAccentPolicy: "state"

    property bool barIdleDim: false
    property int barIdleTimeout: 120000 // ms
    property real barIdleOpacity: 0.55

    // Master switch for the small decorative motion touches — icon shakes
    // (mute/DND toggles), blips (connectivity state changes, unread-badge
    // pops), tray-icon pop-in, and the workspace-switch slide. Doesn't touch
    // the plain 80ms hover/state colour fades used throughout — those are
    // state feedback, not motion for its own sake. Named after the
    // OS-standard "reduce motion" accessibility setting (macOS, Windows,
    // Android all call it exactly that) rather than inventing new wording.
    property bool reduceMotion: false

    // Third-party tray/notification-app icons are full-colour bitmaps outside
    // the theme system. "native": untouched. "desaturate": grey at rest, full
    // colour on hover. "dim": opacity 0.75 at rest, 1.0 on hover.
    // "desaturate+dim": both at once — greyed and dimmed at rest, full colour
    // and opacity on hover. Worth it for icons that are both saturated and
    // near-white (e.g. some apps' tray glyphs), which are the most
    // burn-in-prone thing on the bar otherwise.
    property string trayIconStyle: "dim"

    // ── Timing ──
    property int osdDuration: 1500
    property int osdStartupDelay: 2000
    property int tooltipHideDelay: 300
    property int networkPollFallback: 60000

    // ── Notification panel ──
    // Silence toasts while a window is truly fullscreen (not merely maximized).
    property bool suppressInFullscreen: true
    // Additionally require the window to signal playback (idle inhibit or a
    // video/game content type). Stricter — useful if you fullscreen windows as
    // a general window-management gesture rather than for media.
    property bool suppressRequiresPlayback: false

    // ── Notifications ──
    property int notifPanelWidth: 360
    property int notifPanelHeight: 420
    property int maxStoredNotifications: 20
    // Set above 1 to stack multiple live toasts. Set to 0 to disable them.
    property int maxLiveNotificationToasts: 1
    // Countdown-to-auto-expire indicator on normal-urgency toasts. "hairline":
    // 2px bar along the bottom edge. "circle": a ring in the corner where the
    // close button sits, swapping to the close button on hover. "none": no
    // visual (still auto-expires on the same schedule). Hovering the toast
    // always pauses the countdown, regardless of style.
    property string toastCountdownStyle: "circle"
    // "all": every monitor gets its own copy (today's behaviour). "focused":
    // only the currently-focused monitor shows it, matching how macOS/Windows
    // both only ever show on one display — but tracking the focused one
    // dynamically rather than a fixed "main"/"primary" display, which is the
    // actual complaint people have with both of those (banner lands on
    // whichever monitor you're not looking at).
    property string toastMonitorMode: "all"
    // Collapse consecutive same-app notifications in the centre into one
    // expandable card. Grouping is by app identity (whatever the sender set
    // as its name over DBus), not message content — tools that default to a
    // generic name when called without an explicit app name (e.g. plain
    // `notify-send` without -a) will group together even with different text.
    property bool groupNotifications: true

    // ── External commands ──
    property string volumeApp: "pwvucontrol"
    property string wirelessApp: "iwgtk"
    property string bluetoothApp: "blueman-manager"
    property string wirelessToggleScript: ""
    property string bluetoothToggleScript: ""

    // D2 control centre (v1, deliberately scoped down — see the design
    // brief's own note that this is a feature project, not a restyle).
    // When true, replaces the 7 individual status cells (volume, mic,
    // ethernet, wifi, wireguard, bluetooth, notifications) with a single
    // digest cell that opens a tabbed panel (Notifications/Audio/Network/
    // Themes) with its own embedded content — Media (MPRIS) and clipboard
    // history are not implemented.
    property bool useControlCentre: false
    property int controlCentreWidth: 320
}
