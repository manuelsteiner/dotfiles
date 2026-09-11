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

    width: 36
    height: 36
    radius: Config.radiusCell
    color: cell.cellDisabled ? "transparent"
        : cell.active ? Theme.elev2
        : cell.pressed ? Theme.press
        : cell.hovered ? Theme.hover
        : "transparent"
    border.width: (cell.active || cell.urgent) ? 1 : 0
    border.color: cell.active ? cell.accentColor : cell.urgentColor

    Behavior on color { ColorAnimation { duration: 80 } }
    Behavior on border.color { ColorAnimation { duration: 80 } }
}
