import QtQuick
import QtQuick.Effects

// Shared chrome for every popout, OSD-adjacent panel and menu (A3 rule 3):
// elev2 fill, 1px edge border, radiusPopout, a 1px edgeTop inner highlight on
// the top edge, and the halo shadow. Drop-in replacement for the old
// `Rectangle { color: Theme.surface; border.color: Theme.overlay; ... }`
// chrome — content still goes inside as normal children.
//
// The shadow-casting background (`bg`) and the clipped content area are
// deliberately separate items: `clip` and `layer.effect` on the same item
// force the layer's texture to the item's exact bounds, which hard-cuts the
// shadow's blur at that boundary instead of letting it fade out past the
// edge (a "blocky" rectangular shadow instead of a soft halo).
Item {
    id: frame
    property alias radius: bg.radius
    property alias border: bg.border
    default property alias data: content.data

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Config.radiusPopout
        color: Theme.elev2
        border.width: 1
        border.color: Theme.edge

        layer.enabled: Config.popoutHalo
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.90)
            shadowBlur: 0.6
            shadowVerticalOffset: 8
            shadowHorizontalOffset: 0
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: 1
        color: Theme.edgeTop
    }

    Item {
        id: content
        anchors.fill: parent
        clip: true
    }
}
