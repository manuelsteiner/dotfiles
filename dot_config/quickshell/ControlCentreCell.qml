import Quickshell
import QtQuick
import QtQuick.Layouts

// D2 control centre digest cell (v1) — replaces the individual volume, mic,
// ethernet, wifi, wireguard, bluetooth and notifications cells when
// Config.useControlCentre is true. The bar's underline (here, the accent
// border) carries the one glanceable fact: something is worth a look.
BarCell {
    id: ccBlock
    Layout.alignment: Qt.AlignHCenter
    property var screen: null
    hovered: ccMA.containsMouse
    pressed: ccMA.pressed
    // Digest: only something to report if there's an unread notification or
    // DND is on — matches the notification bell's own "state" semantics,
    // since a settings-style icon has no natural resting hue of its own.
    active: root.storedNotifications.length > 0 || root.dndEnabled
    urgent: false
    accentColor: Theme.accent

    Text {
        anchors.centerIn: parent
        font.family: Config.fontFamily
        font.pixelSize: 18
        color: ccBlock.glyphColor
        text: "󰍜"
    }

    MouseArea {
        id: ccMA
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            var pos = parent.mapToItem(null, 0, parent.height / 2)
            root.toggleControlCentre(ccBlock.screen)
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                var pos = parent.mapToItem(null, 0, parent.height / 2)
                root.showTooltip("controlcentre", "Control Centre", pos.y, ccBlock.screen)
            } else {
                root.hideTooltip("controlcentre")
            }
        }
    }
}
