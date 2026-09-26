import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root
    property string state: "hidden"
    property var levels: []
    property int elapsedSeconds: 0
    readonly property bool listening: state === "listening"
    readonly property bool processing: state === "processing"
    readonly property bool showKeyHint: Config.voxtypeShowKeyHint && listening && elapsedSeconds < 3
    // Keep the card width stable between listening and processing so the
    // frozen timer remains in the same calm, right-hand position.
    readonly property int recordingContentWidth: 237
    implicitWidth: recordingContentWidth + 44
    // An explicit property makes the folding geometry visible to the parent
    // window rather than leaving it to a layout's implicit-size update.
    property real capsuleHeight: showKeyHint ? 88 : 60
    implicitHeight: capsuleHeight
    visible: state !== "hidden"

    function formatDuration(seconds) { return Math.floor(seconds / 60) + ":" + (seconds % 60).toString().padStart(2, "0") }
    function shortcutSymbol(key) {
        return key
    }
    readonly property var shortcutParts: {
        const keys = Config.voxtypeKeybind.split("+")
        const parts = []
        for (let index = 0; index < keys.length; ++index) {
            if (index > 0) parts.push({ text: "+", keycap: false })
            parts.push({ text: shortcutSymbol(keys[index]), keycap: true })
        }
        return parts
    }
    Behavior on implicitWidth { NumberAnimation { duration: Config.reduceMotion ? 0 : 220; easing.type: Easing.OutQuint } }
    Behavior on capsuleHeight { NumberAnimation { duration: Config.reduceMotion ? 0 : 260; easing.type: Easing.OutQuint } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        clip: true
        color: Theme.elev2
        border.width: 1
        border.color: Theme.edge
        layer.enabled: true
        layer.effect: MultiEffect {
            readonly property real baseLuminance: 0.2126 * Theme.base.r + 0.7152 * Theme.base.g + 0.0722 * Theme.base.b
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, baseLuminance < 0.5 ? 0.35 : 0.18)
            shadowBlur: 0.3
            shadowScale: 1.0
            shadowVerticalOffset: 4
        }

        RowLayout {
            id: content
            width: root.recordingContentWidth
            height: 32
            x: Math.round((parent.width - width) / 2)
            // Keep the primary row centered in the compact 60px pill while
            // the optional lower hint area folds away beneath it.
            y: 14
            spacing: 16
            Item {
                visible: root.listening; Layout.preferredWidth: visible ? 11 : 0; Layout.preferredHeight: 11
                Layout.leftMargin: root.listening ? 9 : 0
                Rectangle {
                    anchors.centerIn: parent; width: 11; height: 11; radius: 5.5; color: Theme.microphoneColor
                    SequentialAnimation on scale { running: root.listening && !Config.reduceMotion; loops: Animation.Infinite; NumberAnimation { from: 1; to: 2.6; duration: 1400; easing.type: Easing.OutCubic } }
                    SequentialAnimation on opacity { running: root.listening && !Config.reduceMotion; loops: Animation.Infinite; NumberAnimation { from: 0.6; to: 0; duration: 1400; easing.type: Easing.OutCubic } }
                }
                Rectangle { anchors.centerIn: parent; width: 11; height: 11; radius: 5.5; color: Theme.microphoneColor }
            }
            DictationWaveform { visible: root.listening; Layout.preferredWidth: visible ? implicitWidth : 0; Layout.preferredHeight: implicitHeight; levels: root.levels }
            Item {
                visible: root.processing; Layout.preferredWidth: visible ? 22 : 0; Layout.preferredHeight: 22
                Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: "transparent"; border.width: 3.5; border.color: Theme.divider }
                Item {
                    anchors.fill: parent
                    RotationAnimator on rotation { running: root.processing && !Config.reduceMotion; from: 0; to: 360; duration: 3000; loops: Animation.Infinite }
                    // Reuse the toast ring's Canvas drawing approach. This is
                    // a real rounded arc, rotating continuously rather than
                    // a countdown or a radial tick.
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.lineWidth = 3.5
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Theme.microphoneColor
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, width / 2 - 2,
                                -Math.PI / 2, -Math.PI / 2 + Math.PI * 1.35)
                            ctx.stroke()
                        }
                        onVisibleChanged: if (visible) requestPaint()
                    }
                }
            }
            Text {
                visible: root.processing; Layout.preferredWidth: visible ? implicitWidth : 0; text: "Transcribing"
                font { family: Config.fontFamily; pixelSize: 17; weight: Font.Medium }
                color: Theme.text
                SequentialAnimation on opacity {
                    running: root.processing && !Config.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.5; duration: 1200 }
                    NumberAnimation { from: 0.5; to: 1; duration: 1200 }
                }
            }
            // Processing gets a flexible middle region; listening omits it.
            // This keeps the timer against the same right edge in both states.
            Item { visible: root.processing; Layout.fillWidth: root.processing }
            Item {
                id: timerAndHint
                readonly property int timerWidth: 48
                Layout.preferredWidth: timerWidth
                Layout.preferredHeight: 28

                Text {
                    id: timer
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: timerAndHint.timerWidth
                    text: root.formatDuration(root.elapsedSeconds)
                    font { family: Config.fontFamily; pixelSize: 16; weight: Font.Medium; features: { "tnum": 1 } }
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.75)
                }
            }
        }

        Item {
            id: keyHint
            visible: root.showKeyHint || opacity > 0
            // Repeater's generated children do not reliably contribute to an
            // enclosing Row's measured width. Size this group explicitly so
            // its visible bounds, rather than an implementation detail, are
            // what gets centered.
            width: shortcutKeys.width + 4 + stopLabel.implicitWidth
            height: 22
            // The animated microphone pulse makes the primary row read a
            // touch left-heavy, so this small optical correction aligns the
            // hint with the perceived (rather than just geometric) center.
            x: Math.round((parent.width - width) / 2) - 6
            y: parent.height - height - 12
            opacity: root.showKeyHint ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.reduceMotion ? 0 : 120 } }

            Row {
                id: shortcutKeys
                spacing: 4
                Repeater {
                    model: root.shortcutParts
                    delegate: Item {
                        required property var modelData
                        width: partLabel.implicitWidth + (modelData.keycap ? 12 : 0)
                        height: 22
                        Rectangle {
                            anchors.fill: parent; visible: modelData.keycap; radius: 6
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                        }
                        Text {
                            id: partLabel; anchors.centerIn: parent; text: modelData.text
                            font { family: Config.fontFamily; pixelSize: modelData.keycap ? 14 : 12; weight: Font.Medium }
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.70)
                        }
                    }
                }
            }
            Text {
                id: stopLabel
                x: shortcutKeys.width + 4
                anchors.verticalCenter: parent.verticalCenter
                text: "to stop"
                font { family: Config.fontFamily; pixelSize: 12 }
                color: Theme.subtle
            }
        }
    }
}
