import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: wsRoot
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: wsColumn.implicitWidth
    implicitHeight: wsColumn.implicitHeight

    property bool bgStyle: Config.workspaceStyle === "background"
    property bool outlineStyle: Config.workspaceStyle === "outline"

    property int activeIndex: {
        for (var i = 0; i < Config.workspaces.length; i++) {
            var ws = Config.workspaces[i].ws
            if (Hyprland.workspaces.values.some(w => w.id === ws && w.focused))
                return i
        }
        return 0
    }

    property bool activeHovered: false

    function focusByIndex(index) {
        if (index < 0 || index >= Config.workspaces.length) return
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + Config.workspaces[index].ws + ' })')
    }

    // Right-click a workspace to pull/push it to whichever other monitor
    // it isn't currently on. With exactly two monitors this is a clean
    // toggle; with more than two it moves to the first other one found.
    function moveToOtherMonitor(index) {
        if (index < 0 || index >= Config.workspaces.length) return
        var wsId = Config.workspaces[index].ws
        var ws = Hyprland.workspaces.values.find(w => w.id === wsId)
        if (!ws || !ws.monitor) return
        var other = Hyprland.monitors.values.find(m => m.name !== ws.monitor.name)
        if (!other) return
        // This Hyprland config is Lua-based: Hyprland.dispatch() splices its
        // string into `hl.dispatch(...)`, which needs an hl.dsp.* call, not
        // the classic "moveworkspacetomonitor <ws> <mon>" dispatch string
        // (that silently no-ops). Verified live: hl.dsp.workspace.move
        // requires both `workspace` and `monitor` table keys.
        Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + wsId + ', monitor = "' + other.name + '" })')
        if (Config.workspaceMoveFollowsFocus)
            Hyprland.dispatch('hl.dsp.focus({ workspace = ' + wsId + ' })')
    }

    // Scroll to move focus to the previous/next configured workspace, wrapping
    // at the ends (matches a status bar feel better than clamping). Placed
    // beneath the Column so per-cell clicks still take priority; wheel events
    // fall through to here since the cell MouseAreas don't handle onWheel.
    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            var count = Config.workspaces.length
            if (count === 0) return
            if (wheel.angleDelta.y === 0) return
            var next = (wsRoot.activeIndex + (wheel.angleDelta.y < 0 ? 1 : -1) + count) % count
            wsRoot.focusByIndex(next)
        }
    }

    // Sliding accent background (only in "background" style)
    Rectangle {
        id: highlight
        visible: bgStyle
        width: 36; height: 36; radius: Config.radiusCell
        color: activeHovered ? Theme.accentDim : Theme.accent
        Behavior on color { ColorAnimation { duration: 80 } }
        x: wsColumn.x + (wsColumn.width - width) / 2
        y: activeIndex * (36 + 4)

        Behavior on y {
            enabled: Config.enableWorkspaceTransition
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    Column {
        id: wsColumn
        spacing: 4

        Repeater {
            id: wsRepeater
            model: Config.workspaces
            delegate: Rectangle {
                id: wsCell
                required property var modelData
                required property int index
                width: 36; height: 36; radius: Config.radiusCell
                property bool active: index === activeIndex
                property bool hovered: wsMA.containsMouse
                property bool urgent: Hyprland.workspaces.values.some(w => w.id === modelData.ws && w.urgent)

                color: {
                    if (outlineStyle) {
                        if (active) return Theme.elev2
                        if (hovered) return Theme.hover
                        return "transparent"
                    }
                    if (bgStyle) {
                        if (hovered) return active ? "transparent" : Theme.accent
                        if (urgent && !active) return Theme.urgentColor
                        return "transparent"
                    }
                    // "icon" style
                    return hovered ? Theme.accent : "transparent"
                }
                Behavior on color { ColorAnimation { duration: 80 } }

                border.width: outlineStyle && (active || urgent) ? 1 : 0
                border.color: (outlineStyle && active && urgent) ? Theme.urgentColor
                    : (outlineStyle && active) ? Theme.accent
                    : Theme.urgentColor
                Behavior on border.color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    font.family: Config.fontFamily
                    font.pixelSize: 18
                    color: {
                        if (outlineStyle) {
                            if (parent.active) return Theme.accent
                            if (wsMA.containsMouse) return Theme.text
                            if (parent.urgent) return Theme.urgentColor
                            return Theme.subtle
                        }
                        if (bgStyle) {
                            if (parent.active) return Theme.base
                            if (wsMA.containsMouse) return Theme.base
                            if (parent.urgent) return Theme.base
                            return Theme.subtle
                        }
                        // "icon" style
                        if (wsMA.containsMouse) return Theme.base
                        if (parent.active) return Theme.accent
                        if (parent.urgent) return Theme.urgentColor
                        return Theme.subtle
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
                MouseArea {
                    id: wsMA
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            wsRoot.moveToOtherMonitor(parent.index)
                        else
                            wsRoot.focusByIndex(parent.index)
                    }
                    onContainsMouseChanged: {
                        if (parent.active) activeHovered = containsMouse
                    }
                }
            }
        }
    }
}
