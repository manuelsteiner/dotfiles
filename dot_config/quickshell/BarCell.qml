import QtQuick

// Shared state chrome for every interactive bar cell (A4). Callers own their
// own MouseArea/Text/icon; this just supplies the fill/border/glyph-color
// for rest/hover/press/active/urgent/disabled so no module inverts to a full
// accent block on its own anymore.
Rectangle {
    id: cell

    property color accentColor: Theme.accent
    property color urgentColor: Theme.urgentColor
    property bool active: false
    property bool urgent: false
    property bool cellDisabled: false
    property bool hovered: false
    property bool pressed: false

    readonly property color glyphColor: cell.cellDisabled ? Theme.muted
        : cell.active ? cell.accentColor
        : cell.urgent ? cell.urgentColor
        : (cell.hovered || cell.pressed) ? Theme.text
        : Theme.subtle

    // Popout rows sit on PopoutFrame's own opaque elev2 backdrop, so a
    // translucent Theme.press fill just blends cleanly on top of it. Bar
    // cells have nothing behind them but the transparent bar window, so the
    // same translucent color would let the desktop show through — a solid
    // opaque cell suddenly turning into a wallpaper-tinted hole on hover.
    // Qt.tint bakes the same ink onto elev2 as an opaque color instead,
    // matching how elev1/elev2 themselves are derived from `base` in Theme.qml.
    readonly property color activeHoverColor: Qt.tint(Theme.elev2, Theme.press)

    width: 36
    height: 36
    radius: Config.radiusCell
    color: cell.cellDisabled ? "transparent"
        : cell.active ? ((cell.hovered || cell.pressed) ? cell.activeHoverColor : Theme.elev2)
        : cell.pressed ? Theme.press
        : cell.hovered ? Theme.hover
        : "transparent"
    border.width: (cell.active || cell.urgent) ? 1 : 0
    border.color: cell.active ? cell.accentColor : cell.urgentColor

    Behavior on color { ColorAnimation { duration: 80 } }
    Behavior on border.color { ColorAnimation { duration: 80 } }
}
