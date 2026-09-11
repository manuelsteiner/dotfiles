//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    property bool _osdReady: false
    Timer {
        interval: Config.osdStartupDelay
        running: true
        onTriggered: root._osdReady = true
    }

    // ── Volume OSD state ──
    property real volOsdValue: 0
    property bool volOsdMuted: false
    property bool volOsdVisible: false
    property bool _suppressVolumeOsd: false

    Connections {
        target: Config.enableVolumeOsd ? (Pipewire.defaultAudioSink?.audio ?? null) : null
        function onVolumeChanged() { root.showVolumeOsd() }
        function onMutedChanged() { root.showVolumeOsd() }
    }

    function showVolumeOsd() {
        if (!Config.enableVolumeOsd || !root._osdReady || root._suppressVolumeOsd) return
        var sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio) return
        root.volOsdValue = sink.audio.volume
        root.volOsdMuted = sink.audio.muted
        root.micOsdVisible = false
        root.volOsdVisible = true
        volOsdHideTimer.restart()
    }

    Timer {
        id: volOsdHideTimer
        interval: Config.osdDuration
        onTriggered: root.volOsdVisible = false
    }

    Timer {
        id: volumePanelOsdSuppressionTimer
        interval: 150
        onTriggered: root._suppressVolumeOsd = false
    }

    function setPanelVolume(node, volume) {
        if (!node?.audio) return
        root._suppressVolumeOsd = true
        root.volOsdVisible = false
        volOsdHideTimer.stop()
        node.audio.volume = Math.max(0, Math.min(1, volume))
        volumePanelOsdSuppressionTimer.restart()
    }

    // ── Microphone OSD state ──
    property real micOsdValue: 0
    property bool micOsdMuted: false
    property bool micOsdVisible: false
    property bool _suppressMicOsd: false

    Connections {
        target: Config.enableMicrophoneOsd ? (Pipewire.defaultAudioSource?.audio ?? null) : null
        function onVolumeChanged() { root.showMicOsd() }
        function onMutedChanged() { root.showMicOsd() }
    }

    function showMicOsd() {
        if (!Config.enableMicrophoneOsd || !root._osdReady || root._suppressMicOsd) return
        var source = Pipewire.defaultAudioSource
        if (!source || !source.audio) return
        root.micOsdValue = source.audio.volume
        root.micOsdMuted = source.audio.muted
        root.volOsdVisible = false
        root.micOsdVisible = true
        micOsdHideTimer.restart()
    }

    Timer {
        id: micOsdHideTimer
        interval: Config.osdDuration
        onTriggered: root.micOsdVisible = false
    }

    Timer {
        id: micPanelOsdSuppressionTimer
        interval: 150
        onTriggered: root._suppressMicOsd = false
    }

    function setPanelMicVolume(node, volume) {
        if (!node?.audio) return
        root._suppressMicOsd = true
        root.micOsdVisible = false
        micOsdHideTimer.stop()
        node.audio.volume = Math.max(0, Math.min(1, volume))
        micPanelOsdSuppressionTimer.restart()
    }

    // ── Brightness OSD state ──
    property real brightOsdValue: 0
    property bool brightOsdVisible: false
    property bool _brightInitialized: false

    Timer {
        id: brightOsdHideTimer
        interval: Config.osdDuration
        onTriggered: root.brightOsdVisible = false
    }

    // ── Panel manager ──
    // Close all exclusive panels, optionally keeping one open.
    function closeAllPanels(except) {
        // Hide tooltip when opening a panel (the tooltip source is likely the icon being clicked)
        if (except !== undefined) {
            tooltipHideTimer.stop()
            root.tooltipVisible = false
        }
        if (except !== "calendar")      root.calendarVisible = false
        if (except !== "power")         root.powerMenuVisible = false
        if (except !== "notifPanel")    root.notifPanelVisible = false
        if (except !== "trayMenu")      { root.trayMenuVisible = false; root.trayMenuHandle = null }
        if (except !== "volumePanel")   root.volumePanelVisible = false
        if (except !== "micPanel")      root.micPanelVisible = false
        if (except !== "btPanel")       root.btPanelVisible = false
        if (except !== "wgPanel")       root.wgPanelVisible = false
        if (except !== "wifiPanel")     root.wifiPanelVisible = false
    }

    // Screen a popout was opened from — popouts only render on this one
    // instead of every connected monitor. Shared across all of them since
    // closeAllPanels already keeps them mutually exclusive.
    property var activePanelScreen: null

    // ── Volume panel state ──
    property bool volumePanelVisible: false
    property real volumePanelY: 0

    function toggleVolumePanel(globalY, screen) {
        var show = !root.volumePanelVisible
        root.closeAllPanels(show ? "volumePanel" : undefined)
        root.volumePanelY = globalY
        if (show) root.activePanelScreen = screen
        root.volumePanelVisible = show
    }

    // ── Microphone panel state ──
    property bool micPanelVisible: false
    property real micPanelY: 0

    function toggleMicPanel(globalY, screen) {
        var show = !root.micPanelVisible
        root.closeAllPanels(show ? "micPanel" : undefined)
        root.micPanelY = globalY
        if (show) root.activePanelScreen = screen
        root.micPanelVisible = show
    }

    // ── Bluetooth panel state ──
    property bool btPanelVisible: false
    property real btPanelY: 0

    function toggleBtPanel(globalY, screen) {
        var show = !root.btPanelVisible
        root.closeAllPanels(show ? "btPanel" : undefined)
        root.btPanelY = globalY
        if (show) root.activePanelScreen = screen
        root.btPanelVisible = show
    }

    // ── WireGuard panel state ──
    property bool wgPanelVisible: false
    property real wgPanelY: 0

    function toggleWgPanel(globalY, screen) {
        var show = !root.wgPanelVisible
        root.closeAllPanels(show ? "wgPanel" : undefined)
        root.wgPanelY = globalY
        if (show) root.activePanelScreen = screen
        root.wgPanelVisible = show
    }

    // ── Wireless panel state ──
    property bool wifiPanelVisible: false
    property real wifiPanelY: 0

    function toggleWifiPanel(globalY, screen) {
        var show = !root.wifiPanelVisible
        root.closeAllPanels(show ? "wifiPanel" : undefined)
        root.wifiPanelY = globalY
        if (show) root.activePanelScreen = screen
        root.wifiPanelVisible = show
    }

    // ── Calendar state ──
    property bool calendarVisible: false

    function toggleCalendar(screen) {
        var show = !root.calendarVisible
        root.closeAllPanels(show ? "calendar" : undefined)
        if (show) root.activePanelScreen = screen
        root.calendarVisible = show
    }

    // ── Power menu state ──
    property bool powerMenuVisible: false
    Process { id: powerCmdProc; running: false }

    function togglePowerMenu(screen) {
        var show = !root.powerMenuVisible
        root.closeAllPanels(show ? "power" : undefined)
        if (show) root.activePanelScreen = screen
        root.powerMenuVisible = show
    }

    // ── Tray context menu state ──
    property var trayMenuHandle: null
    property bool trayMenuVisible: false
    property real trayMenuY: 0

    function openTrayMenu(menuHandle, globalY, screen) {
        if (root.trayMenuVisible && root.trayMenuHandle === menuHandle) {
            root.closeTrayMenu()
            return
        }
        root.closeAllPanels("trayMenu")
        root.activePanelScreen = screen
        root.trayMenuHandle = menuHandle
        root.trayMenuY = globalY
        root.trayMenuVisible = true
    }

    function closeTrayMenu() {
        root.trayMenuVisible = false
        root.trayMenuHandle = null
    }

    // ── Tooltip state ──
    property string tooltipText: ""
    property real tooltipY: 0
    property bool tooltipVisible: false
    property string _tooltipSource: ""
    // Screen the tooltip was raised from — same scoping as activePanelScreen,
    // so a hover on one monitor doesn't ghost a tooltip onto every other one.
    property var tooltipScreen: null

    Timer {
        id: tooltipHideTimer
        interval: Config.tooltipHideDelay
        onTriggered: root.tooltipVisible = false
    }

    function showTooltip(sourceId, text, globalY, screen) {
        // Suppress tooltip when the corresponding popup is already open
        if ((sourceId === "vol"    && root.volumePanelVisible) ||
            (sourceId === "mic"    && root.micPanelVisible)    ||
            (sourceId === "bt"     && root.btPanelVisible)     ||
            (sourceId === "wg"     && root.wgPanelVisible)     ||
            (sourceId === "net"    && root.wifiPanelVisible)   ||
            (sourceId === "clock"  && root.calendarVisible)    ||
            (sourceId === "notif"  && root.notifPanelVisible)) {
            return
        }
        tooltipHideTimer.stop()
        if (root._tooltipSource === sourceId && root.tooltipText === text && root.tooltipVisible) return
        root._tooltipSource = sourceId
        root.tooltipText = text
        root.tooltipY = globalY
        root.tooltipScreen = screen
        root.tooltipVisible = true
    }

    function hideTooltip(sourceId) {
        if (root._tooltipSource === sourceId) tooltipHideTimer.restart()
    }

    // ── Notification state ──
    property bool dndEnabled: false
    // The toast area defaults to one notification. The panel remains the
    // complete notification history.
    property var toastNotifications: []
    property var storedNotifications: []
    property bool notifPanelVisible: false

    // Auto-DND driven by the focused window being fullscreen. Notifications are
    // still stored while suppressed – only the toast is withheld.
    property bool autoDnd: false
    readonly property bool notifSuppressed: root.dndEnabled || root.autoDnd

    Process {
        id: activeWindowProc
        command: ["hyprctl", "activewindow", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var win = null
                try { win = JSON.parse(this.text) } catch (e) { win = null }

                // fullscreen: 0 = none, 1 = maximized, 2 = fullscreen
                if (!win || win.fullscreen !== 2) { root.autoDnd = false; return }
                if (!Config.suppressRequiresPlayback) { root.autoDnd = true; return }

                var ct = win.contentType ?? "none"
                root.autoDnd = win.inhibitingIdle === true || ct === "video" || ct === "game"
            }
        }
    }

    function refreshAutoDnd() {
        if (!Config.suppressInFullscreen) { root.autoDnd = false; return }
        if (!activeWindowProc.running) activeWindowProc.running = true
    }

    Timer {
        id: autoDndDebounce
        interval: 80
        onTriggered: root.refreshAutoDnd()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "fullscreen":
            case "activewindow":
            case "activewindowv2":
            case "closewindow":
            case "openwindow":
            case "workspace":
            case "focusedmon":
                autoDndDebounce.restart()
            }
        }
    }

    Component.onCompleted: root.refreshAutoDnd()

    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        onNotification: notification => {
            if (!Config.enableNotifications) return
            notification.tracked = true

            // The underlying notification object closes itself once the
            // sender's own expire_timeout elapses (many apps, e.g.
            // notify-send, default to ~5s) — that's unrelated to whether the
            // user has seen or dismissed it from the centre. Only drop it
            // from the live toast layer here; `tracked = true` above keeps
            // the object alive so it can keep showing in storedNotifications
            // until the user explicitly dismisses it or clears all.
            notification.closed.connect(function() {
                root.toastNotifications = root.toastNotifications.filter(n => n !== notification)
            })

            // Always store the notification (sorted by urgency)
            var stored = root.storedNotifications.slice()
            var urgency = notification.urgency ?? 1
            var idx = 0
            for (; idx < stored.length; idx++) {
                if ((stored[idx].urgency ?? 1) < urgency) break
            }
            stored.splice(idx, 0, notification)
            if (stored.length > Config.maxStoredNotifications) {
                var dropped = stored.pop()
                dropped.tracked = false
                dropped.dismiss()
            }
            root.storedNotifications = stored

            // F-1: low-urgency notifications never toast — they land in the
            // centre (stored above) only. Critical notifications bypass DND
            // (manual or auto-fullscreen); normal notifications are still
            // withheld while suppressed.
            var isCritical = (notification.urgency ?? 1) === NotificationUrgency.Critical
            var isLow = (notification.urgency ?? 1) === NotificationUrgency.Low
            if (!isLow && (!root.notifSuppressed || isCritical) && stored.indexOf(notification) !== -1) {
                var toasts = root.toastNotifications.filter(n => n !== notification)
                toasts.unshift(notification)
                root.toastNotifications = toasts.slice(0, Math.max(0, Config.maxLiveNotificationToasts))
            }
        }
    }

    // Toast expired by timer – remove from toasts but keep in stored
    function expireToast(notification) {
        root.toastNotifications = root.toastNotifications.filter(n => n !== notification)
    }

    // User explicitly dismissed a toast – remove from both
    function dismissNotification(notification) {
        notification.tracked = false
        notification.dismiss()
        root.toastNotifications = root.toastNotifications.filter(n => n !== notification)
        root.storedNotifications = root.storedNotifications.filter(n => n !== notification)
    }

    // Dismiss a single stored notification (from the panel)
    function dismissStoredNotification(notification) {
        notification.tracked = false
        notification.dismiss()
        root.toastNotifications = root.toastNotifications.filter(n => n !== notification)
        root.storedNotifications = root.storedNotifications.filter(n => n !== notification)
        if (root.storedNotifications.length === 0) root.notifPanelVisible = false
    }

    function clearAllNotifications() {
        // Dismissing can synchronously emit `closed`. Clear UI state first so
        // those callbacks cannot overwrite a partially cleared queue.
        var notifications = root.storedNotifications.slice()
        root.toastNotifications = []
        root.storedNotifications = []
        root.notifPanelVisible = false

        for (var i = 0; i < notifications.length; i++) {
            var notification = notifications[i]
            notification.tracked = false
            notification.dismiss()
        }
    }

    function toggleNotifPanel(screen) {
        var show = !root.notifPanelVisible
        root.closeAllPanels(show ? "notifPanel" : undefined)
        if (show) root.activePanelScreen = screen
        root.notifPanelVisible = show
    }

    // ── Assemble ──
    Bar {}
    CalendarPanel {}
    VolumePanel {}
    MicrophonePanel {}
    BluetoothPanel {}
    WirelessPanel {}
    WireguardPanel {}
    VolumeOsd {}
    MicrophoneOsd {}
    BrightnessOsd {}
    PowerMenu {}
    TrayContextMenu {}
    TooltipPanel {}
    NotificationToasts {}
    NotificationPanel {}
}
