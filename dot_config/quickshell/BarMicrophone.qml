import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

BarCell {
    id: micBlock
    Layout.alignment: Qt.AlignHCenter
    height: Config.enableMicrophoneBar ? 42 : 36
    property var screen: null
    property var source: Pipewire.defaultAudioSource
    property real vol: source?.audio?.volume ?? 0
    property bool muted: source?.audio?.muted ?? true
    hovered: micMA.containsMouse
    pressed: micMA.pressed
    // "always": hue at rest, grey to subtle when muted (today's look).
    // "state": rest at subtle always — muted is a routine, often-intentional
    // state, not something worth a persistent accent border.
    active: Config.barAccentPolicy === "always" && !micBlock.muted
    urgent: false
    accentColor: Theme.microphoneColor

    PwObjectTracker { objects: [micBlock.source] }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Config.enableMicrophoneBar ? -4 : 0
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: micBlock.glyphColor
        text: micBlock.muted ? "󰍭" : "󰍬"
    }

    // Microphone level bar (toggle via Config.enableMicrophoneBar)
    Rectangle {
        visible: Config.enableMicrophoneBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        width: 24; height: 3; radius: 1.5
        color: Theme.divider
        Behavior on color { ColorAnimation { duration: 80 } }

        Rectangle {
            width: parent.width * Math.min(micBlock.vol, 1.0)
            height: parent.height; radius: parent.radius
            color: micBlock.glyphColor
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 80 } }
        }
    }

    MouseArea {
        id: micMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (micBlock.source?.audio)
                    micBlock.source.audio.muted = !micBlock.source.audio.muted
                else
                    micMuteToggle.running = true
                root.showMicOsd()
            } else if (Config.enableMicrophonePanel) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.toggleMicPanel(pos.y, micBlock.screen)
            } else {
                micAppProc.running = true
            }
        }
        onWheel: wheel => {
            if (micBlock.source?.audio) {
                var step = 0.05
                if (wheel.angleDelta.y > 0)
                    micBlock.source.audio.volume = Math.min(micBlock.source.audio.volume + step, 1.0)
                else if (wheel.angleDelta.y < 0)
                    micBlock.source.audio.volume = Math.max(micBlock.source.audio.volume - step, 0.0)
            } else {
                if (wheel.angleDelta.y > 0)
                    micUp.running = true
                else if (wheel.angleDelta.y < 0)
                    micDown.running = true
            }
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.showTooltip("mic",
                    Math.round(micBlock.vol * 100) + "%"
                    + (micBlock.muted ? " (muted)" : ""), pos.y)
            } else {
                root.hideTooltip("mic")
            }
        }
    }

    Process { id: micAppProc; command: [Config.volumeApp]; running: false }
    // wpctl fallbacks when PipeWire QML bindings aren't available
    Process { id: micMuteToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]; running: false }
    Process { id: micUp; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "5%+"]; running: false }
    Process { id: micDown; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "5%-"]; running: false }
}
