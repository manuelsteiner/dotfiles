import Quickshell
import QtQuick
import QtQuick.Layouts

BarCell {
    id: clockBlock
    Layout.alignment: Qt.AlignHCenter
    property var screen: null
    width: 40
    height: clockCol.implicitHeight + 10
    // Bar.qml sizes the clock's island off `clockItem.implicitHeight` — a
    // plain `height:` binding doesn't feed implicitHeight, so it must be set
    // explicitly too or the island collapses to a near-zero-height sliver.
    implicitHeight: clockCol.implicitHeight + 10
    hovered: clockMA.containsMouse
    pressed: clockMA.pressed
    active: false
    urgent: false

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
            font { family: Config.fontFamily; pixelSize: 18; bold: true; features: { "tnum": 1 } }
            color: Theme.text
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: clockBlock.mmStr
            font { family: Config.fontFamily; pixelSize: 18; bold: true; features: { "tnum": 1 } }
            color: Theme.accent
        }
    }

    MouseArea {
        id: clockMA
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (Config.enableCalendar) root.toggleCalendar(clockBlock.screen)
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.showTooltip("clock", clockBlock.tooltipStr, pos.y, clockBlock.screen)
            } else {
                root.hideTooltip("clock")
            }
        }
    }
}
