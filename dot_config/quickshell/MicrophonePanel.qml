import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableMicrophonePanel ? Quickshell.screens : []
        PanelWindow {
            id: micPanelWindow
            property var modelData
            screen: modelData
            visible: root.micPanelVisible && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-micpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            PwObjectTracker {
                id: sourceTracker
                objects: {
                    var result = []
                    for (var i = 0; i < Pipewire.nodes.count; i++)
                        result.push(Pipewire.nodes.values[i])
                    return result
                }
            }

            // D-9 keyboard traversal — see VolumePanel.qml's identical pattern.
            readonly property var sourceNodes: {
                var def = []
                var others = []
                for (var i = 0; i < Pipewire.nodes.count; i++) {
                    var n = Pipewire.nodes.values[i]
                    if (n.isSink || n.isStream || !n.audio) continue
                    if (n === Pipewire.defaultAudioSource) def.push(n)
                    else others.push(n)
                }
                return def.concat(others)
            }
            property int focusedIndex: -1
            onVisibleChanged: if (visible) micPanelWindow.focusedIndex = micPanelWindow.sourceNodes.length > 0 ? 0 : -1

            function moveFocus(delta) {
                var n = micPanelWindow.sourceNodes.length
                if (n === 0) return
                micPanelWindow.focusedIndex = Math.max(0, Math.min(n - 1, micPanelWindow.focusedIndex + delta))
            }
            function focusedNode() {
                var idx = micPanelWindow.focusedIndex
                return idx >= 0 && idx < micPanelWindow.sourceNodes.length ? micPanelWindow.sourceNodes[idx] : null
            }
            function activateFocused() {
                var node = micPanelWindow.focusedNode()
                if (node && node !== Pipewire.defaultAudioSource) Pipewire.preferredDefaultAudioSource = node
            }
            function adjustFocusedVolume(delta) {
                var node = micPanelWindow.focusedNode()
                if (!node?.audio) return
                root.setPanelMicVolume(node, node.audio.volume + delta)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.micPanelVisible = false
                focus: true
                Keys.onEscapePressed: root.micPanelVisible = false
                Keys.onUpPressed: micPanelWindow.moveFocus(-1)
                Keys.onDownPressed: micPanelWindow.moveFocus(1)
                Keys.onLeftPressed: micPanelWindow.adjustFocusedVolume(-0.05)
                Keys.onRightPressed: micPanelWindow.adjustFocusedVolume(0.05)
                Keys.onReturnPressed: micPanelWindow.activateFocused()
                Keys.onEnterPressed: micPanelWindow.activateFocused()
            }

            PopoutFrame {
                anchors.left: parent.left
                y: Math.max(Config.gap, Math.min(
                    parent.height - height - Config.gap,
                    root.micPanelY - 18
                ))
                width: 280
                height: panelCol.implicitHeight + 24

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: panelCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Audio Input"
                        font { family: Config.fontFamily; pixelSize: 13; bold: true }
                        color: Theme.text
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

                    // Default source (on top)
                    Repeater {
                        model: Pipewire.nodes
                        delegate: MicNodeDelegate {
                            required property var modelData
                            node: modelData
                            isDefault: modelData === Pipewire.defaultAudioSource
                            isFocused: modelData === micPanelWindow.focusedNode()
                            visible: !modelData.isSink && !modelData.isStream && modelData.audio && isDefault
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            onSetDefault: Pipewire.preferredDefaultAudioSource = modelData
                            onHovered: micPanelWindow.focusedIndex = micPanelWindow.sourceNodes.indexOf(modelData)
                        }
                    }

                    // Other sources
                    Repeater {
                        model: Pipewire.nodes
                        delegate: MicNodeDelegate {
                            required property var modelData
                            node: modelData
                            isDefault: modelData === Pipewire.defaultAudioSource
                            isFocused: modelData === micPanelWindow.focusedNode()
                            visible: !modelData.isSink && !modelData.isStream && modelData.audio && !isDefault
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            onSetDefault: Pipewire.preferredDefaultAudioSource = modelData
                            onHovered: micPanelWindow.focusedIndex = micPanelWindow.sourceNodes.indexOf(modelData)
                        }
                    }
                }
            }
        }
    }

    component MicNodeDelegate: Rectangle {
        id: del
        property var node
        property bool isDefault: false
        property bool isFocused: false
        property real nodeVol: node.audio?.volume || 0
        property bool nodeMuted: node.audio?.muted ?? false
        signal setDefault()
        signal hovered()

        function setVolume(value) {
            root.setPanelMicVolume(del.node, value)
        }

        implicitHeight: visible ? col.height + 16 : 0
        radius: Config.radiusCell
        color: isDefault
            ? (isFocused ? Theme.press : Theme.elev2)
            : (isFocused ? Theme.hover : "transparent")
        border.color: isDefault ? Theme.microphoneColor : "transparent"
        border.width: isDefault ? 1 : 0
        Behavior on color { ColorAnimation { duration: 80 } }

        Column {
            id: col
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 4

            Item {
                width: parent.width; height: 18

                Item {
                    id: iconWrap
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: del.nodeMuted ? "󰍭" : "󰍬"
                        font { family: Config.fontFamily; pixelSize: 14 }
                        color: del.isDefault ? Theme.microphoneColor
                            : del.nodeMuted ? Theme.muted : Theme.subtle
                    }
                }

                Text {
                    anchors.left: iconWrap.right; anchors.leftMargin: 8
                    anchors.right: volText.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: del.node.description || del.node.name || "Unknown"
                    font { family: Config.fontFamily; pixelSize: 12 }
                    color: del.isDefault || del.isFocused ? Theme.text : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 80 } }
                    elide: Text.ElideRight
                }

                Text {
                    id: volText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: del.isFocused || ma.adjustingVolume
                    text: Math.round(del.nodeVol * 100) + "%"
                    font { family: Config.fontFamily; pixelSize: 11; weight: Font.Medium; features: { "tnum": 1 } }
                    color: del.nodeMuted ? Theme.muted : Theme.subtle
                }
            }

            Rectangle {
                id: volumeSlider
                width: parent.width; height: 5; radius: 2.5
                color: del.isFocused ? Theme.hover : Theme.divider
                Rectangle {
                    width: parent.width * Math.min(del.nodeVol, 1.0)
                    height: parent.height; radius: parent.radius
                    color: del.isDefault ? Theme.microphoneColor
                        : del.nodeMuted ? Theme.muted : Theme.subtle
                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: del.hovered()
            property bool adjustingVolume: false
            property bool adjustedVolume: false
            function isOverVolumeSlider(mouse) {
                var sliderPos = volumeSlider.mapToItem(del, 0, 0)
                return mouse.x >= sliderPos.x
                    && mouse.x <= sliderPos.x + volumeSlider.width
                    && mouse.y >= sliderPos.y - 6
                    && mouse.y <= sliderPos.y + volumeSlider.height + 6
            }
            function setVolumeFromMouse(mouse) {
                var sliderPos = volumeSlider.mapToItem(del, 0, 0)
                del.setVolume((mouse.x - sliderPos.x) / volumeSlider.width)
            }
            onPressed: mouse => {
                adjustedVolume = mouse.button === Qt.LeftButton && isOverVolumeSlider(mouse)
                adjustingVolume = adjustedVolume
                if (adjustingVolume) setVolumeFromMouse(mouse)
            }
            onPositionChanged: mouse => {
                if (adjustingVolume && pressed) setVolumeFromMouse(mouse)
            }
            onReleased: adjustingVolume = false
            onClicked: mouse => {
                if (adjustedVolume) {
                    adjustedVolume = false
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    if (del.node.audio)
                        del.node.audio.muted = !del.node.audio.muted
                } else if (!del.isDefault) {
                    del.setDefault()
                }
            }
            onWheel: wheel => {
                if (!del.node.audio) return
                var step = 0.05
                if (wheel.angleDelta.y > 0)
                    del.setVolume(del.nodeVol + step)
                else if (wheel.angleDelta.y < 0)
                    del.setVolume(del.nodeVol - step)
            }
        }
    }
}
