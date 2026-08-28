import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: clockBlock
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: 40
    implicitHeight: clockCol.implicitHeight + 10
    radius: 6
    color: clockMA.containsMouse ? Theme.highlightLow : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    property string hhStr: ""
    property string mmStr: ""
    property string tooltipStr: ""

    function updateClock() {
        var now = new Date()
        var hh = now.getHours()
        var mm = now.getMinutes()
        clockBlock.hhStr = (hh < 10 ? "0" : "") + hh
        clockBlock.mmStr = (mm < 10 ? "0" : "") + mm
        clockBlock.tooltipStr = now.toLocaleDateString(Qt.locale(), "ddd dd MMM yyyy")
    }

    Component.onCompleted: updateClock()

    Timer {
        id: clockTimer
        interval: 60000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            clockBlock.updateClock()
            clockTimer.interval = 60000 - (Date.now() % 60000) + 100
        }
    }

    ColumnLayout {
        id: clockCol
        anchors.centerIn: parent
        spacing: 0
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: clockBlock.hhStr
            font { family: Config.fontFamily; pixelSize: 18; bold: true }
            color: Theme.text
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: clockBlock.mmStr
            font { family: Config.fontFamily; pixelSize: 18; bold: true }
            color: Theme.accent
        }
    }

    MouseArea {
        id: clockMA
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (Config.enableCalendar) root.toggleCalendar()
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.showTooltip("clock", clockBlock.tooltipStr, pos.y)
            } else {
                root.hideTooltip("clock")
            }
        }
    }
}
