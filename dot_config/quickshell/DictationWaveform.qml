import QtQuick

Item {
    id: root
    property var levels: []
    property color accentColor: Theme.microphoneColor
    implicitWidth: 137
    implicitHeight: 32

    Repeater {
        model: 20
        Rectangle {
            required property int index
            width: 4
            height: 8 + Math.round(Math.max(0, Math.min(1, root.levels[index] ?? 0)) * 24)
            radius: 2
            x: index * 7
            anchors.verticalCenter: parent.verticalCenter
            color: root.accentColor
            Behavior on height { NumberAnimation { duration: Config.reduceMotion ? 0 : 60 } }
        }
    }
}
