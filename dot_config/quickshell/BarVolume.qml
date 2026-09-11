import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

BarCell {
    id: volBlock
    Layout.alignment: Qt.AlignHCenter
    height: Config.enableVolumeBar ? 42 : 36
    property var screen: null
    property var sink: Pipewire.defaultAudioSink
    property real vol: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false
    hovered: volMA.containsMouse
    pressed: volMA.pressed
    // "always": hue at rest, grey to subtle when muted (today's look).
    // "state": rest at subtle always — muted is a routine, often-intentional
    // state, not something worth a persistent accent border.
    active: Config.barAccentPolicy === "always" && !volBlock.muted
    urgent: false
    accentColor: Theme.volumeColor

    PwObjectTracker { objects: [volBlock.sink] }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Config.enableVolumeBar ? -4 : 0
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: volBlock.glyphColor
        text: volBlock.muted ? "󰸈"
            : volBlock.vol < 0.33 ? "󰕿"
            : volBlock.vol < 0.66 ? "󰖀" : "󰕾"
    }

    // Volume level bar (toggle via Config.enableVolumeBar)
    Rectangle {
        visible: Config.enableVolumeBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        width: 24; height: 3; radius: 1.5
        color: Theme.divider
        Behavior on color { ColorAnimation { duration: 80 } }

        Rectangle {
            width: parent.width * Math.min(volBlock.vol, 1.0)
            height: parent.height; radius: parent.radius
            color: volBlock.glyphColor
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 80 } }
        }
    }

    MouseArea {
        id: volMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (volBlock.sink?.audio)
                    volBlock.sink.audio.muted = !volBlock.sink.audio.muted
                else
                    volMuteToggle.running = true
                root.showVolumeOsd()
            } else if (Config.enableVolumePanel) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.toggleVolumePanel(pos.y, volBlock.screen)
            } else {
                volAppProc.running = true
            }
        }
        onWheel: wheel => {
            if (volBlock.sink?.audio) {
                var step = 0.05
                if (wheel.angleDelta.y > 0)
                    volBlock.sink.audio.volume = Math.min(volBlock.sink.audio.volume + step, 1.0)
                else if (wheel.angleDelta.y < 0)
                    volBlock.sink.audio.volume = Math.max(volBlock.sink.audio.volume - step, 0.0)
            } else {
                if (wheel.angleDelta.y > 0)
                    volUp.running = true
                else if (wheel.angleDelta.y < 0)
                    volDown.running = true
            }
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.showTooltip("vol",
                    Math.round(volBlock.vol * 100) + "%"
                    + (volBlock.muted ? " (muted)" : ""), pos.y, volBlock.screen)
            } else {
                root.hideTooltip("vol")
            }
        }
    }

    Process { id: volAppProc; command: [Config.volumeApp]; running: false }
    // wpctl fallbacks when PipeWire QML bindings aren't available
    Process { id: volMuteToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; running: false }
    Process { id: volUp; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]; running: false }
    Process { id: volDown; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]; running: false }
}
