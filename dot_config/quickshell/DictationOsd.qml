import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Visual-only Voxtype integration: state comes from the daemon's event-driven
// state file; the waveform uses its packaged audio-level bridge.
Scope {
    id: dictation
    property string daemonState: "idle"
    property double recordingStartedAt: 0
    property int elapsedSeconds: 0
    property var levelHistory: Array(20).fill(0)
    readonly property bool active: ["recording", "transcribing", "streaming"].indexOf(daemonState) >= 0
    readonly property string visualState: daemonState === "recording" ? "listening"
        : active ? "processing" : "hidden"

    function setDaemonState(value) {
        const state = value.trim().toLowerCase()
        const next = ["idle", "recording", "streaming", "transcribing"].indexOf(state) >= 0 ? state : "idle"
        if (next !== daemonState && next !== "idle") root.voxtypeOsdScreen = Hyprland.focusedMonitor?.name ?? ""
        if (next === "recording" && daemonState !== "recording") {
            recordingStartedAt = Date.now(); elapsedSeconds = 0; levelHistory = Array(20).fill(0); elapsedTimer.start()
        } else if (next !== "recording") elapsedTimer.stop()
        daemonState = next
    }

    function pushLevel(rms) {
        if (daemonState !== "recording") return
        const next = levelHistory.slice(1)
        next.push(Math.max(0, Math.min(1, rms / 0.35)))
        levelHistory = next
    }

    FileView {
        path: Config.voxtypeStateFile; watchChanges: true; printErrors: false
        onLoaded: dictation.setDaemonState(text() || "idle")
        onLoadFailed: dictation.setDaemonState("idle")
        onFileChanged: reload()
    }

    Process {
        command: ["voxtype-audio-bridge"]
        running: Config.enableVoxtypeOsd
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                try { const frame = JSON.parse(line); if (typeof frame.rms === "number") dictation.pushLevel(frame.rms) } catch (_) {}
            }
        }
    }

    Timer {
        id: elapsedTimer; interval: 1000; repeat: true
        onTriggered: dictation.elapsedSeconds = Math.max(0, Math.floor((Date.now() - dictation.recordingStartedAt) / 1000))
    }

    Variants {
        model: Config.enableVoxtypeOsd ? Quickshell.screens : []
        PanelWindow {
            id: panel
            property var modelData
            screen: modelData
            visible: dictation.active && (Config.osdMonitorMode !== "focused" || modelData.name === root.voxtypeOsdScreen)
            implicitHeight: 88 + Config.voxtypeOsdBottomInset + 32
            anchors { bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.namespace: "qs-dictation-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Entire surface remains click-through: Voxtype has no reliable
            // error/done callback yet, so this version deliberately has no
            // actions that could steal focus from the dictated-into app.
            mask: Region { intersection: Intersection.Subtract; x: 0; y: 0; width: panel.width; height: panel.height }
            readonly property int usableLeft: Config.effectiveBarWidth + Config.gap

            DictationCapsule {
                width: implicitWidth; height: implicitHeight
                state: dictation.visualState; levels: dictation.levelHistory; elapsedSeconds: dictation.elapsedSeconds
                x: panel.usableLeft + Math.round((panel.width - panel.usableLeft - width) / 2)
                // Keep the recording row fixed while the lower hint area
                // fades and the capsule clips upward into its compact form.
                y: panel.height - 88 - Config.voxtypeOsdBottomInset
            }
        }
    }
}
