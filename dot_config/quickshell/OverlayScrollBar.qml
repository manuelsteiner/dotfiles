import QtQuick

// One scrollbar treatment for every overflowable list (A6): 4px wide, thumb
// radius 2, no track, no arrows, overlay (not inset — floats over the
// content's right padding instead of reserving a gutter). Visible only while
// the list can actually scroll; fades in on hover/scroll, out ~1s after the
// last scroll event. Wheel scrolling on the Flickable works regardless of
// visibility, since this never intercepts wheel events.
Item {
    id: scrollbar

    property Flickable flickable
    property real rightMargin: 2

    anchors.right: parent.right
    anchors.rightMargin: rightMargin
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 4
    z: 10

    readonly property bool canScroll: flickable && flickable.contentHeight > flickable.height
    readonly property real thumbHeight: canScroll
        ? Math.max(20, height * flickable.height / flickable.contentHeight)
        : height
    readonly property real thumbY: canScroll
        ? (height - thumbHeight) * flickable.contentY / Math.max(1, flickable.contentHeight - flickable.height)
        : 0

    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 80 } }

    Timer {
        id: fadeTimer
        interval: 1000
        onTriggered: if (!thumbMA.containsMouse && !thumbMA.pressed) scrollbar.opacity = 0
    }

    Connections {
        target: scrollbar.flickable
        function onContentYChanged() {
            if (scrollbar.canScroll) { scrollbar.opacity = 1; fadeTimer.restart() }
        }
    }

    Rectangle {
        visible: scrollbar.canScroll
        x: 0
        y: scrollbar.thumbY
        width: 4
        height: scrollbar.thumbHeight
        radius: 2
        color: (thumbMA.containsMouse || thumbMA.pressed) ? Theme.text : Theme.subtle
    }

    MouseArea {
        id: thumbMA
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeVerCursor
        enabled: scrollbar.canScroll

        property real pressY: 0
        property real contentAtPress: 0

        onEntered: { if (scrollbar.canScroll) scrollbar.opacity = 1; fadeTimer.stop() }
        onExited: fadeTimer.restart()
        onPressed: mouse => {
            pressY = mouse.y
            contentAtPress = scrollbar.flickable.contentY
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            var scrollRange = scrollbar.flickable.contentHeight - scrollbar.flickable.height
            var trackRange = scrollbar.height - scrollbar.thumbHeight
            scrollbar.flickable.contentY = Math.max(0, Math.min(scrollRange,
                contentAtPress + (mouse.y - pressY) * scrollRange / Math.max(1, trackRange)))
        }
        onReleased: fadeTimer.restart()
    }
}
