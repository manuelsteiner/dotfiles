import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

BarCell {
    id: bellBlock
    Layout.alignment: Qt.AlignHCenter
    property var screen: null
    // storedNotifications is sorted by urgency (descending), so the head
    // being Critical means at least one Critical entry is pending.
    readonly property bool anyCritical: root.storedNotifications.length > 0
        && root.storedNotifications[0].urgency === NotificationUrgency.Critical
    hovered: bellMA.containsMouse
    pressed: bellMA.pressed
    // "always": hue at rest, grey to subtle when suppressed (today's look).
    // "state": rest at subtle, accent when there's something to report
    // (unread notifications). DND on its own no longer colors the icon —
    // it's a deliberate action, not an abnormal condition to flag.
    active: Config.barAccentPolicy === "always"
        ? !root.notifSuppressed
        : root.storedNotifications.length > 0
    urgent: false
    accentColor: Theme.notificationColor

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: bellBlock.glyphColor
        text: root.notifSuppressed ? "󰪑"
            : root.storedNotifications.length > 0 ? "󰂚" : "󰂜"
    }

    Rectangle {
        // Outlined, not filled (A7 burn-in note): this badge is lit for
        // hours at a time, so only the stroke stays saturated.
        visible: root.storedNotifications.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.rightMargin: 1
        width: Math.max(14, badgeText.implicitWidth + 6)
        height: 14
        radius: 7
        // Elev2 fill + a 1px hairline ring — reads as "just an outline"
        // against the near-black bar without being literally transparent
        // (which let the bell glyph show through the badge oddly).
        color: Theme.elev2
        border.width: 1
        border.color: bellBlock.anyCritical ? Theme.red : Theme.redDim

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.storedNotifications.length > 99
                ? "99+" : root.storedNotifications.length.toString()
            font { family: Config.fontFamily; pixelSize: 10; bold: true; features: { "tnum": 1 } }
            color: bellBlock.anyCritical ? Theme.red : Theme.redDim
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
                root.toggleNotifPanel(bellBlock.screen)
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
                root.showTooltip("notif", tip, pos.y, bellBlock.screen)
            } else {
                root.hideTooltip("notif")
            }
        }
    }
}
