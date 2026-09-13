import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: wsRoot
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: wsColumn.implicitWidth
    implicitHeight: wsColumn.implicitHeight

    // Each bar is tied to one QScreen. Its monitor owns the authoritative
    // activeWorkspace; a workspace's monitor only says where it lives.
    property var screen
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property int activeWorkspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    property bool bgStyle: Config.workspaceStyle === "background"
    property bool outlineStyle: Config.workspaceStyle === "outline"

    property int activeIndex: {
        for (var i = 0; i < Config.workspaces.length; i++) {
            if (Config.workspaces[i].ws === activeWorkspaceId) return i
        }
        return 0
    }

    property bool activeHovered: false

    // Component-wise colour lerp — no Qt built-in for this.
    function mixColor(a, b, t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        )
    }

    // Outline style's indicator (below) never animates colour — it stays a
    // static elev2 fill / accent border the whole time, and its momentum
    // comes from a geometry bump instead (see the indicator itself). This
    // just drives *where* it's travelling to/from on each workspace switch.
    property int lastActiveIndex: 0
    Component.onCompleted: {
        lastActiveIndex = activeIndex
        indicator.srcY = activeIndex * (36 + 4)
        indicator.tgtY = indicator.srcY
        indicator.p = 1
    }
    onActiveIndexChanged: {
        var newY = activeIndex * (36 + 4)
        if (!outlineStyle || Config.reduceMotion || !Config.enableWorkspaceTransition) {
            indicator.srcY = newY
            indicator.tgtY = newY
            indicator.p = 1
        } else {
            indicator.srcY = indicator.y
            indicator.tgtY = newY
            pAnim.duration = Math.min(400, 160 + 45 * Math.abs(activeIndex - lastActiveIndex))
            pAnim.restart()
        }
        lastActiveIndex = activeIndex
    }

    function focusByIndex(index) {
        if (index < 0 || index >= Config.workspaces.length) return
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + Config.workspaces[index].ws + ' })')
    }

    function wsIndexForId(id) {
        for (var i = 0; i < Config.workspaces.length; i++) {
            if (Config.workspaces[i].ws === id) return i
        }
        return -1
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

    // Detects a workspace's monitor actually changing, from *any* trigger —
    // this bar's own right-click above, the other bar's right-click, or
    // Hyprland's own "mainMod + SHIFT + O" keybind, which bypasses the bar
    // entirely. A plain snapshot-and-diff on a reactive binding catches all
    // three the same way, with no need to special-case who initiated it.
    readonly property var workspaceMonitorById: {
        var map = {}
        var vals = Hyprland.workspaces.values
        for (var i = 0; i < vals.length; i++)
            map[vals[i].id] = vals[i].monitor ? vals[i].monitor.name : ""
        return map
    }
    property var _prevWorkspaceMonitorById: null

    // Hyprland's own workspace.move dispatcher shifts input focus to the
    // destination monitor as part of the move (your active workspace takes
    // your focus with it) — by the time workspaceMonitorById's diff below
    // notices anything, Hyprland.focusedMonitor already reports the
    // destination, not the monitor you were actually looking at when you
    // triggered the move. Track focus changes ourselves so we always have
    // the monitor that was focused *immediately before* the latest change,
    // one step behind the live value.
    property string _lastFocusedName: Hyprland.focusedMonitor?.name ?? ""
    property string _previousFocusedName: _lastFocusedName
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            wsRoot._previousFocusedName = wsRoot._lastFocusedName
            wsRoot._lastFocusedName = Hyprland.focusedMonitor?.name ?? ""
        }
    }

    // A workspace being pushed/pulled is user-initiated — like the shake
    // effects — so it only plays on whichever bar you're actually looking
    // at, per Config.interactiveEffectMonitorMode, not on every monitor.
    readonly property bool isFocusedScreen: Config.interactiveEffectMonitorMode !== "focused"
        || monitor?.name === _previousFocusedName
    onWorkspaceMonitorByIdChanged: {
        if (_prevWorkspaceMonitorById === null) {
            _prevWorkspaceMonitorById = workspaceMonitorById
            return
        }
        var anyChanged = false
        for (var idStr in workspaceMonitorById) {
            // A workspace being freshly created (first-ever focus on an
            // unvisited number, or recreated after being destroyed while
            // empty/unfocused — Hyprland drops non-persistent workspaces
            // with no windows) briefly has no monitor at all before
            // settling on the current one. That reads in this diff as a
            // "" -> "realmonitor" transition, indistinguishable from an
            // actual relocation unless both sides are required to already
            // be real, non-empty monitor names.
            if (_prevWorkspaceMonitorById[idStr] !== undefined
                && _prevWorkspaceMonitorById[idStr] !== ""
                && workspaceMonitorById[idStr] !== ""
                && _prevWorkspaceMonitorById[idStr] !== workspaceMonitorById[idStr]) {
                anyChanged = true
                if (isFocusedScreen && !Config.reduceMotion) {
                    var idx = wsIndexForId(parseInt(idStr))
                    var cell = idx >= 0 ? wsRepeater.itemAt(idx) : null
                    if (cell) cell.playMoveCue()
                }
            }
        }
        // Quickshell's Hyprland IPC listener doesn't refresh
        // monitor.activeWorkspace on this event class on its own — without
        // this, both bars keep showing whichever workspace was active
        // before the move until some unrelated event (e.g. switching
        // workspaces once) happens to force a resync.
        if (anyChanged) {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
        }
        _prevWorkspaceMonitorById = workspaceMonitorById
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
            enabled: Config.enableWorkspaceTransition && !Config.reduceMotion
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    // Outline style's indicator — per Claude Design's "Patch - Workspace
    // Transition": the flash wasn't a curve problem, it was structural.
    // elev2 → accent → elev2 is a detour (two events, peak-then-recede) no
    // matter how it's timed, InOutCubic-eased or held. The fix moves the
    // "peak" from colour to geometry instead: fill/border stay static
    // forever, and the momentum reads through the shape elongating in the
    // direction of travel (leading edge commits before the trailing edge
    // lets go) — a rigid rectangle sliding at constant shape can only ever
    // read as a hand-off, never as one continuous object in motion.
    //
    // p (0=source, 1=target) is the only animated property; position and
    // height both derive from it so they can't drift apart. `bump` is
    // sin(π·p), which — because p itself is already InOutCubic-eased —
    // peaks exactly at p's maximum velocity, so elongation is proportional
    // to speed for free without a second animation curve to keep in sync.
    Rectangle {
        id: indicator
        visible: outlineStyle
        readonly property real cell: 36
        readonly property real elong: 20 // px of elongation at peak
        property real p: 1
        property real srcY: 0
        property real tgtY: 0
        readonly property real bump: Math.sin(Math.PI * p)
        readonly property real down: tgtY >= srcY ? 1 : 0

        x: wsColumn.x + (wsColumn.width - cell) / 2
        width: cell
        height: cell + elong * bump
        y: srcY + (tgtY - srcY) * p - (1 - down) * elong * bump

        radius: Config.radiusCell
        color: Theme.elev2 // never animated
        border.width: 1
        border.color: Theme.accent // never animated

        NumberAnimation {
            id: pAnim
            target: indicator
            property: "p"
            from: 0
            to: 1
            easing.type: Easing.InOutCubic
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
                // Newly-urgent (not already-urgent-on-load) gets the same
                // attention blip connectivity state changes use elsewhere
                // (BT/VPN icons) — a rising edge, not every urgent poll
                // tick. Tried adding breathing pulses on top; decided
                // against it — too much motion for a status bar, the blip
                // plus the static border/colour was already the right call.
                onUrgentChanged: if (urgent) wsIconBlip.trigger()

                // Pushed/pulled to another monitor: the icon leaves to one
                // side and re-enters from the other, in place, on this same
                // cell — not a real cross-window hand-off (every bar always
                // shows every configured workspace regardless of which
                // monitor it's actually attached to), just a self-contained
                // "this one just relocated" cue.
                property real moveOffset: 0
                property real moveOpacity: 1
                transform: [Translate { x: wsCell.moveOffset }]
                opacity: wsCell.moveOpacity
                function playMoveCue() { moveCue.restart() }
                SequentialAnimation {
                    id: moveCue
                    ParallelAnimation {
                        NumberAnimation { target: wsCell; property: "moveOffset"; to: 28; duration: 150; easing.type: Easing.InCubic }
                        NumberAnimation { target: wsCell; property: "moveOpacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    }
                    PropertyAction { target: wsCell; property: "moveOffset"; value: -28 }
                    ParallelAnimation {
                        NumberAnimation { target: wsCell; property: "moveOffset"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: wsCell; property: "moveOpacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    }
                }

                // Vertical overlap between this cell's slot and the
                // indicator, as a 0–1 fraction — a plain binding, not an
                // animation, so it can't drift out of sync with the
                // indicator's own geometry. Drives the glyph colour below:
                // the accent is carried across rather than handed over, and
                // cells the indicator passes through mid-flight light up
                // briefly, which is what actually reads as "one continuous
                // thing in motion" rather than the indicator's shape alone.
                readonly property real slotY: index * (36 + 4)
                readonly property real lit: outlineStyle ? Math.max(0,
                    Math.min(slotY + 36, indicator.y + indicator.height) - Math.max(slotY, indicator.y)
                ) / 36 : 0

                // Active-cell fill/border for outline style is owned
                // entirely by the floating indicator above (same
                // relationship background style's cells already have with
                // `highlight`) — this rectangle only ever shows hover/urgent
                // states of its own.
                color: {
                    if (outlineStyle) return (!active && hovered) ? Theme.hover : "transparent"
                    if (bgStyle) {
                        if (hovered) return active ? "transparent" : Theme.accent
                        if (urgent && !active) return Theme.urgentColor
                        return "transparent"
                    }
                    // "icon" style
                    return hovered ? Theme.accent : "transparent"
                }
                Behavior on color { ColorAnimation { duration: 80 } }

                border.width: outlineStyle && urgent ? 1 : 0
                border.color: urgent ? Theme.urgentColor : "transparent"
                Behavior on border.color { ColorAnimation { duration: 80 } }

                Text {
                    id: wsIcon
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    font.family: Config.fontFamily
                    font.pixelSize: 18
                    color: {
                        if (outlineStyle) {
                            if (wsMA.containsMouse) return Theme.text
                            if (parent.urgent) return Theme.urgentColor
                            return wsRoot.mixColor(Theme.subtle, Theme.accent, parent.lit)
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
                IconBlip { id: wsIconBlip; target: wsIcon }
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
