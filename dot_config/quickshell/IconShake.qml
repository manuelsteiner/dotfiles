import QtQuick

// Tactile feedback for a toggle you just clicked (mute, DND) — a quick
// horizontal wiggle. Implemented as a Translate meant to be plugged into the
// target's `transform:` list, not a direct animation of `x` — these icons
// are anchor-positioned (anchors.horizontalCenter/centerIn), and anchors
// continuously re-assert x/y, silently overriding any direct write to them.
// A transform composes on top of anchor-computed layout instead of fighting
// it. Translate has no default property (unlike Item), so the animation is
// attached via an explicit property rather than nested as an implicit child.
Translate {
    id: root
    function trigger() { if (!Config.reduceMotion) _seq.restart() }

    property SequentialAnimation _seq: SequentialAnimation {
        NumberAnimation { target: root; property: "x"; to: -4; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "x"; to: 4; duration: 85; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "x"; to: -3; duration: 85; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "x"; to: 2; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "x"; to: 0; duration: 70; easing.type: Easing.OutQuad }
    }
}
