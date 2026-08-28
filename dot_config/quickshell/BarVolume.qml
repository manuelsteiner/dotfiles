import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: volBlock
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: Config.enableVolumeBar ? 42 : 36; radius: 6
    property var sink: Pipewire.defaultAudioSink
    property real vol: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false
    color: volMA.containsMouse
        ? (volBlock.muted ? Theme.muted : Theme.volumeColor)
        : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    PwObjectTracker { objects: [volBlock.sink] }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Config.enableVolumeBar ? -4 : 0
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: volMA.containsMouse ? Theme.base
            : volBlock.muted ? Theme.muted : Theme.volumeColor
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
        color: volMA.containsMouse ? Theme.highlightMed
            : volBlock.muted ? Theme.muted : Theme.highlightMed
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            width: parent.width * Math.min(volBlock.vol, 1.0)
            height: parent.height; radius: parent.radius
            color: volMA.containsMouse ? Theme.base
                : (volBlock.muted ? Theme.muted : Theme.volumeColor)
            Behavior on width { NumberAnimation { duration: 80 } }
            Behavior on color { ColorAnimation { duration: 100 } }
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
                root.toggleVolumePanel(pos.y)
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
                    + (volBlock.muted ? " (muted)" : ""), pos.y)
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
