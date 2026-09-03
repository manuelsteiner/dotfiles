import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.alignment: Qt.AlignHCenter
    width: 36; height: 36; radius: 6
    color: bellMA.containsMouse
        ? (root.notifSuppressed ? Theme.muted : Theme.notificationColor)
        : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: bellMA.containsMouse ? Theme.base
            : root.notifSuppressed ? Theme.muted : Theme.notificationColor
        text: root.notifSuppressed ? "󰪑"
            : root.storedNotifications.length > 0 ? "󰂚" : "󰂜"
    }

    Rectangle {
        visible: root.storedNotifications.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.rightMargin: 1
        width: Math.max(14, badgeText.implicitWidth + 6)
        height: 14
        radius: 7
        color: Theme.red

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.storedNotifications.length > 99
                ? "99+" : root.storedNotifications.length.toString()
            font { family: Config.fontFamily; pixelSize: 9; bold: true }
            color: Theme.base
        }
    }

    MouseArea {
        id: bellMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.dndEnabled = !root.dndEnabled
            } else {
                root.toggleNotifPanel()
            }
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                var tip = root.dndEnabled ? "Do Not Disturb (on)"
                    : root.autoDnd ? "Silenced (fullscreen)"
                    : "Notifications"
                if (root.storedNotifications.length > 0)
                    tip += " (" + root.storedNotifications.length + ")"
                root.showTooltip("notif", tip, pos.y)
            } else {
                root.hideTooltip("notif")
            }
        }
    }
}
