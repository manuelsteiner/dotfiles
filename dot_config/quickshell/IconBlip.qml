import QtQuick

// Softens a glyph swap or connectivity state change that isn't necessarily
// something you just clicked (network up/down, VPN tunnel state, Bluetooth
// power) — a quick shrink-and-recover scale bounce, distinct from IconShake's
// wiggle, which is reserved for toggles you directly triggered.
SequentialAnimation {
    id: blip
    property Item target: null

    function trigger() {
        if (blip.target && !Config.reduceMotion) blip.restart()
    }

    // A bigger dip reads as more noticeable at the same duration than a
    // longer, shallow one — motion-design guidance (Material/NN-g/Apple)
    // consistently ties duration to distance travelled, not the other way
    // around, and 270ms total is already mid-pack for a small feedback
    // animation.
    NumberAnimation { target: blip.target; property: "scale"; to: 0.55; duration: 110; easing.type: Easing.OutQuad }
    NumberAnimation { target: blip.target; property: "scale"; to: 1.0; duration: 190; easing.type: Easing.OutBack }
}
